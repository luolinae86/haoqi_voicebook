# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"
require "zip"
require "nokogiri"

# EPUB 导入异步任务
# 流程：从 OSS 下载 EPUB → 解压 → 解析 → 图片/CSS/Nav 上传 OSS → 更新引用 → 保存页面到 DB → 重新打包 EPUB → 上传
# 注意：Sidekiq 7 要求参数为 JSON 原生类型，使用 Hash with string keys
class EpubImportWorker
  include Sidekiq::Job
  sidekiq_options queue: "export", retry: 2

  # @param args [Hash] {"book_id"=>Integer, "epub_oss_key"=>String}
  def perform(args)
    book_id = args["book_id"]
    epub_oss_key = args["epub_oss_key"]

    book = Book.find(book_id)
    book.update!(epub_export_status: :exporting, epub_export_error: nil)

    # 按书名创建 OSS 目录
    sanitized_title = sanitize_dir_name(book.title)
    styles_key    = "#{sanitized_title}/styles/book.css"
    nav_key       = "#{sanitized_title}/nav.xhtml"
    images_prefix = "#{sanitized_title}/images"
    epub_key      = "#{sanitized_title}/#{sanitized_title}.epub"

    Dir.mktmpdir("epub-import-#{book_id}") do |tmp_dir|
      tmp_path = Pathname.new(tmp_dir)
      oss_service = AliyunOssService.new

      # 1. 从 OSS 下载 EPUB
      epub_path = tmp_path.join("source.epub")
      oss_service.download_file(object_key: epub_oss_key, local_path: epub_path)
      Rails.logger.info("[EpubImport] Downloaded EPUB from OSS: #{epub_oss_key} (#{epub_path.size} bytes)")

      # 2. 解压
      unzip_dir = tmp_path.join("unzipped")
      Zip::File.open(epub_path.to_s) do |zip_file|
        zip_file.each do |entry|
          dest = unzip_dir.join(entry.name)
          FileUtils.mkdir_p(dest.dirname)
          entry.extract(dest.to_s) unless dest.exist?
        end
      end
      Rails.logger.info("[EpubImport] EPUB extracted")

      # 3. 解析 content.opf
      opf_path = find_opf(unzip_dir)
      raise StandardError, "无法找到 EPUB content.opf" unless opf_path&.exist?

      epub_title, spine_items, manifest, page_entries = parse_opf(opf_path)

      # 更新书名（如果 Book 尚无书名）
      book.update!(title: epub_title) if book.title.blank? && epub_title.present?
      sanitized_title = sanitize_dir_name(book.title)
      styles_key    = "#{sanitized_title}/styles/book.css"
      nav_key       = "#{sanitized_title}/nav.xhtml"
      images_prefix = "#{sanitized_title}/images"
      epub_key      = "#{sanitized_title}/#{sanitized_title}.epub"

      # 清空已有页面（全部重建）
      book.ebook_pages.destroy_all
      Rails.logger.info("[EpubImport] Cleared existing pages for book ##{book_id}")

      # 4. 上传 book.css
      css_path = unzip_dir.join("OEBPS/styles/book.css")
      styles_oss_url = nil
      if css_path.exist?
        styles_oss_url = oss_service.upload_file(
          local_path: css_path,
          object_key: styles_key,
          content_type: "text/css"
        )
        Rails.logger.info("[EpubImport] Stylesheet uploaded: #{styles_oss_url}")
      end

      # 5. 上传所有图片到 OSS
      image_urls = {}
      images_dir = unzip_dir.join("OEBPS/images")
      if images_dir.exist?
        images_dir.each_child do |img_file|
          next unless img_file.file?

          object_key = "#{images_prefix}/#{img_file.basename}"
          oss_url = oss_service.upload_file(
            local_path: img_file,
            object_key: object_key,
            content_type: infer_content_type(img_file.basename.to_s)
          )
          image_urls["images/#{img_file.basename}"] = oss_url
          image_urls["../images/#{img_file.basename}"] = oss_url
        end
        Rails.logger.info("[EpubImport] #{image_urls.size} images uploaded to OSS")
      end

      # 6. 处理每页 XHTML：更新引用 → 保存到 DB
      pages_dir = unzip_dir.join("OEBPS/pages")
      page_entries.each do |page_entry|
        page_file = pages_dir.join(File.basename(page_entry[:href]))
        next unless page_file.exist?

        xhtml = File.read(page_file)
        xhtml = update_references(xhtml, image_urls, styles_oss_url)

        # 从 viewport meta 提取宽高
        page_width, page_height = extract_viewport_size(xhtml)

        ebook_page = book.ebook_pages.create!(
          page_number: page_entry[:page_number],
          xhtml_content: xhtml,
          rich_content: {},
          page_width: page_width || 857,
          page_height: page_height || 1168
        )
      end
      Rails.logger.info("[EpubImport] #{book.ebook_pages.count} pages saved to DB")

      # 7. 更新 nav.xhtml 引用并上传
      nav_path = unzip_dir.join("OEBPS/nav.xhtml")
      nav_oss_url = nil
      if nav_path.exist?
        nav_content = File.read(nav_path)
        nav_content = update_references(nav_content, image_urls, styles_oss_url)
        File.write(nav_path, nav_content)
        nav_oss_url = oss_service.upload_file(
          local_path: nav_path,
          object_key: nav_key,
          content_type: "application/xhtml+xml"
        )
        Rails.logger.info("[EpubImport] Navigation uploaded: #{nav_oss_url}")
      end

      # 8. 重新打包 EPUB
      new_epub_path = tmp_path.join("output.epub")
      build_epub(new_epub_path, unzip_dir)
      Rails.logger.info("[EpubImport] EPUB repackaged: #{new_epub_path.size} bytes")

      # 9. 上传 EPUB 到 OSS
      epub_oss_url = oss_service.upload_file(
        local_path: new_epub_path,
        object_key: epub_key,
        content_type: "application/epub+zip"
      )
      Rails.logger.info("[EpubImport] EPUB uploaded to OSS: #{epub_oss_url}")

      # 10. 更新 Book
      book.reload.update!(
        epub_export_status: :completed,
        epub_oss_key: epub_key,
        epub_oss_url: epub_oss_url,
        styles_oss_url: styles_oss_url,
        nav_oss_url: nav_oss_url,
        page_count: book.ebook_pages.count,
        import_status: :ready,
        epub_export_error: nil
      )
    end

    Rails.logger.info("[EpubImport] Complete for book ##{book_id}")
  rescue StandardError => e
    book = Book.find_by(id: book_id)
    book&.update!(epub_export_status: :export_failed, epub_export_error: e.message)
    Rails.logger.error("[EpubImport] Failed for book ##{book_id}: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    raise
  end

  private

  # 从 container.xml 找 OPF 路径
  def find_opf(unzip_dir)
    container = unzip_dir.join("META-INF/container.xml")
    return unless container.exist?

    doc = Nokogiri::XML(File.read(container))
    rootfile = doc.at_xpath("//xmlns:rootfile")
    return unless rootfile

    unzip_dir.join(rootfile["full-path"])
  end

  # 解析 content.opf，返回 [title, spine_items, manifest, page_entries]
  def parse_opf(opf_path)
    content = File.read(opf_path)
    doc = Nokogiri::XML(content)

    title_ns = doc.at_xpath("//dc:title", "dc" => "http://purl.org/dc/elements/1.1/")
    title = title_ns&.text&.strip

    # 解析 manifest
    manifest = {}
    doc.xpath("//opf:item", "opf" => "http://www.idpf.org/2007/opf").each do |item|
      manifest[item["id"]] = { href: item["href"], media_type: item["media-type"] }
    end

    # 按 spine 顺序提取页面
    spine_items = doc.xpath("//opf:itemref", "opf" => "http://www.idpf.org/2007/opf")
    page_number = 0
    page_entries = spine_items.map do |itemref|
      item = manifest[itemref["idref"]]
      next unless item && item[:href]&.start_with?("pages/")

      page_number += 1
      {
        page_number: page_number,
        href: item[:href],
        media_type: item[:media_type]
      }
    end.compact

    [title, spine_items, manifest, page_entries]
  end

  # 替换 XHTML 中的图片和 CSS 引用为 OSS URL
  def update_references(xhtml, image_urls, styles_oss_url)
    image_urls.each do |rel_path, oss_url|
      xhtml = xhtml.gsub(/src="#{Regexp.escape(rel_path)}"/, "src=\"#{oss_url}\"")
    end
    if styles_oss_url
      xhtml = xhtml.gsub(/href="#{Regexp.escape("../styles/book.css")}"/, "href=\"#{styles_oss_url}\"")
      xhtml = xhtml.gsub(/href="#{Regexp.escape("styles/book.css")}"/, "href=\"#{styles_oss_url}\"")
    end
    xhtml
  end

  # 从 viewport meta 提取宽高
  def extract_viewport_size(xhtml)
    match = xhtml.match(/viewport.*?width=(\d+),height=(\d+)/)
    return [match[1].to_f, match[2].to_f] if match

    [nil, nil]
  end

  # 重新打包 EPUB（mimetype 必须 STORE 无压缩且第一个写入）
  def build_epub(output_path, unzip_dir)
    Zip::OutputStream.open(output_path.to_s) do |zip|
      # mimetype 必须第一个且无压缩
      mimetype_path = unzip_dir.join("mimetype")
      if mimetype_path.exist?
        zip.put_next_entry("mimetype", nil, nil, Zip::COMPRESSION_METHOD_STORE)
        zip.write(File.read(mimetype_path))
      end

      # 其余文件正常压缩
      unzip_dir.each_child do |entry|
        next if entry.basename.to_s == "mimetype"
        add_to_zip(zip, entry, "")
      end
    end
  end

  def add_to_zip(zip, entry, prefix)
    if entry.directory?
      entry.each_child { |child| add_to_zip(zip, child, "#{prefix}#{entry.basename}/") }
    else
      zip.put_next_entry("#{prefix}#{entry.basename}")
      zip.write(File.read(entry))
    end
  end

  def sanitize_dir_name(title)
    sanitized = title.to_s.gsub(/[\\\/:*?"<>|]/, "")
    sanitized.strip
  end

  def infer_content_type(filename)
    ext = File.extname(filename).downcase
    case ext
    when ".png" then "image/png"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".jpx" then "image/jpx"
    when ".gif" then "image/gif"
    else "application/octet-stream"
    end
  end
end
