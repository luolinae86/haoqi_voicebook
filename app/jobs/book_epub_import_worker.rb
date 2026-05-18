# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"
require "zip"
require "nokogiri"

# EPUB 导入异步任务（按 Book 级别）
# 流程：从 book.content_file_url 下载 EPUB → 提取目录 → 提取每页 XHTML → 计算字数
class BookEpubImportWorker
  include Sidekiq::Job

  sidekiq_options queue: "import", retry: 2

  # @param args [Hash] {"book_id"=>Integer, "epub_oss_key"=>String}
  def perform(args)
    args = args.symbolize_keys
    book_id = args[:book_id]
    epub_oss_key = args[:epub_oss_key]

    book = Book.find(book_id)
    return if book.import_status == 'ready'

    book.update!(import_status: :processing, import_error_message: nil)

    Dir.mktmpdir("book-epub-import-#{book_id}") do |tmp_dir|
      tmp_path = Pathname.new(tmp_dir)

      # 1. 从 OSS 下载 EPUB
      epub_path = tmp_path.join("source.epub")
      oss_service = AliyunOssService.new
      oss_service.download_file(object_key: epub_oss_key, local_path: epub_path)
      Rails.logger.info("[BookEpubImport] Downloaded EPUB from OSS: #{epub_oss_key}")

      # 2. 解压 EPUB
      extract_dir = tmp_path.join("epub")
      FileUtils.mkdir_p(extract_dir)
      Zip::File.open(epub_path.to_s) do |zip|
        zip.each do |entry|
          dest = File.join(extract_dir, entry.name)
          FileUtils.mkdir_p(File.dirname(dest))
          entry.extract(dest)
        end
      end

      # 3. 解析 EPUB 结构
      container_path = extract_dir.join("META-INF/container.xml")
      raise "Invalid EPUB: missing container.xml" unless container_path.exist?

      container = Nokogiri::XML(File.read(container_path))
      opf_path_rel = container.at_xpath("//c:rootfile", "c" => "urn:oasis:names:tc:opendocument:xmlns:container")["full-path"]
      opf_dir = File.dirname(opf_path_rel)
      opf_path = extract_dir.join(opf_path_rel)

      opf = Nokogiri::XML(File.read(opf_path))

      # 4. 提取 spine（阅读顺序）
      spine_items = {}
      opf.xpath("//opf:item", "opf" => "http://www.idpf.org/2007/opf").each do |item|
        spine_items[item["id"]] = item["href"]
      end

      spine_refs = []
      opf.xpath("//opf:itemref", "opf" => "http://www.idpf.org/2007/opf").each do |itemref|
        idref = itemref["idref"]
        spine_refs << spine_items[idref] if spine_items[idref]
      end

      # 5. 提取 TOC（从 nav.xhtml 或 toc.ncx）
      toc_entries = extract_toc(opf, extract_dir, opf_dir)

      # 6. 提取并上传 CSS 样式表到 OSS
      styles_urls = upload_css_files(opf, extract_dir, opf_dir, oss_service, sanitized_title: sanitize_dir_name(book.name))

      # 7. 提取并上传所有图片到 OSS，建立相对路径到 OSS URL 的映射
      image_url_map = upload_images(opf, extract_dir, opf_dir, oss_service, sanitized_title: sanitize_dir_name(book.name))

      # 去重 spine_refs（同一 href 可能在 spine 中被多次引用）
      # 保留每个 href 的第一次出现，同时收集所有 TOC 匹配
      unique_spine = []
      seen_hrefs = Set.new
      spine_refs.each do |href|
        unless seen_hrefs.include?(href)
          seen_hrefs.add(href)
          unique_spine << href
        end
      end

      # 8. 导入每页 XHTML 和章节
      page_number = 1
      total_word_count = 0
      sanitized_title = sanitize_dir_name(book.name)
      chapter_number = 0

      Book.transaction do
        book.ebook_pages.delete_all
        book.book_chapters.delete_all

        unique_spine.each do |href|
          # 查找所有指向此 href 的 TOC 条目（一个 spine 文件可能对应多个章节，如父子章节指向同一文件）
          matching_tocs = toc_entries.select { |t| t[:href] == href }
          has_toc = matching_tocs.any?

          # 只在 spine 文件有 TOC 对应时才分配 page_number（封面等不在 TOC 中的页面 page_number=0）
          if has_toc
            matching_tocs.each do |matching_toc|
              chapter_number += 1
              book.book_chapters.create!(
                chapter_number: chapter_number,
                chapter_name: matching_toc[:title],
                start_page_number: page_number
              )
            end
          end

          xhtml_path = extract_dir.join(opf_dir, href)
          next unless xhtml_path.exist?

          # 跳过非 TOC 页面（封面等），这些页面不需要创建 EbookPage 记录
          next unless has_toc

          xhtml_content = File.read(xhtml_path)
          # 替换 XHTML 中的相对图片路径为 OSS URL
          xhtml_content = replace_image_paths(xhtml_content, image_url_map, href)
          word_count = extract_word_count(xhtml_content)

          book.ebook_pages.create!(
            page_number: page_number,
            xhtml_content: xhtml_content,
            word_count: word_count
          )

          total_word_count += word_count
          page_number += 1
        end

        book.update!(
          content_type: :ebook,
          word_count: total_word_count,
          page_count: page_number - 1,
          styles_oss_url: styles_urls.first,
          imported_at: Time.current,
          import_status: :ready,
          import_error_message: nil
        )
      end

      Rails.logger.info("[BookEpubImport] EPUB imported: #{book.ebook_pages.count} pages, TOC: #{toc_entries.size} entries")
    end

    Rails.logger.info("[BookEpubImport] Complete for book ##{book_id}")
  rescue StandardError => e
    book = Book.find_by(id: book_id)
    error_msg = e.message
    if e.is_a?(ActiveRecord::RecordInvalid) && e.record
      error_msg = e.record.errors.full_messages.join("; ")
    end
    book&.update!(import_status: :failed, import_error_message: error_msg)
    Rails.logger.error("[BookEpubImport] Failed for book ##{book_id}: #{e.class}: #{error_msg}")
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    raise
  end

  private

  def sanitize_dir_name(title)
    sanitized = title.to_s.gsub(%r{[\\/:*?"<>|]}, "")
    sanitized.strip
  end

  # 将相对路径解析为相对于 OPF 目录的路径
  def resolve_relative_path(href, base_dir)
    return href unless href
    href = href.split("#").first if href.include?("#")
    return href if href.start_with?("http://", "https://", "data:")
    Pathname.new(base_dir.to_s).join(href).cleanpath.to_s.delete_prefix("./")
  end

  def extract_toc(opf, extract_dir, opf_dir)
    toc_entries = []

    # 尝试从 nav.xhtml 提取 TOC（优先查找 properties='nav' 的标准 EPUB3 导航）
    nav_item = opf.xpath("//opf:item[@properties='nav']", "opf" => "http://www.idpf.org/2007/opf").first
    # 如果没找到，回退到包含 nav 名称的 XHTML 文件
    nav_item = opf.xpath("//opf:item[contains(@href, 'nav') and contains(@media-type, 'xhtml')]", "opf" => "http://www.idpf.org/2007/opf").first if nav_item.nil?

    if nav_item
      nav_path = extract_dir.join(opf_dir, nav_item["href"])
      if nav_path.exist?
        nav_dir = File.dirname(nav_item["href"])
        nav = Nokogiri::XML(File.read(nav_path))
        nav.xpath("//nav:nav//nav:a", "nav" => "http://www.w3.org/1999/xhtml").each do |link|
          href = resolve_relative_path(link["href"], nav_dir)
          toc_entries << { title: link.text.strip, href: href }
        end
        return toc_entries if toc_entries.any?
      end
    end

    # 回退到 toc.ncx
    ncx_item = opf.xpath("//opf:item[contains(@media-type, 'x-dtbncx')]", "opf" => "http://www.idpf.org/2007/opf").first
    if ncx_item
      ncx_path = extract_dir.join(opf_dir, ncx_item["href"])
      if ncx_path.exist?
        ncx_dir = File.dirname(ncx_item["href"])
        ncx = Nokogiri::XML(File.read(ncx_path))
        extract_ncx_navpoints(ncx.xpath("//ncx:navMap", "ncx" => "http://www.daisy.org/z3986/2005/ncx/").first, toc_entries, ncx_dir)
      end
    end

    toc_entries
  end

  def extract_ncx_navpoints(parent_node, toc_entries, base_dir = nil)
    return unless parent_node
    ns = { "ncx" => "http://www.daisy.org/z3986/2005/ncx/" }
    parent_node.xpath("./ncx:navPoint", ns).each do |nav_point|
      title = nav_point.at_xpath("ncx:navLabel/ncx:text", ns)&.text
      src = nav_point.at_xpath("ncx:content", ns)&.[]("src")
      href = if base_dir && src
               resolve_relative_path(src.to_s.split("#").first, base_dir)
             else
               src.to_s.split("#").first
             end
      toc_entries << { title: title.to_s.strip, href: href } if title.present?
      # 递归提取子 navPoint
      extract_ncx_navpoints(nav_point, toc_entries, base_dir)
    end
  end

  def extract_word_count(xhtml)
    doc = Nokogiri::HTML(xhtml)
    text = doc.xpath("//body").text.gsub(/\s+/, "")
    text.length
  rescue StandardError
    0
  end

  def upload_css_files(opf, extract_dir, opf_dir, oss_service, sanitized_title:)
    css_urls = []
    opf.xpath("//opf:item[@media-type='text/css']", "opf" => "http://www.idpf.org/2007/opf").each do |item|
      css_href = item["href"]
      css_path = extract_dir.join(opf_dir, css_href)
      next unless css_path.exist?

      object_key = "#{sanitized_title}/styles/#{File.basename(css_href)}"
      css_url = oss_service.upload_file(
        local_path: css_path,
        object_key: object_key,
        content_type: "text/css"
      )
      css_urls << css_url
      Rails.logger.info("[BookEpubImport] CSS uploaded: #{css_url}")
    end
    css_urls
  rescue StandardError => e
    Rails.logger.warn("[BookEpubImport] CSS upload failed: #{e.message}")
    []
  end

  IMAGE_MEDIA_TYPES = %w[image/jpeg image/png image/gif image/svg+xml image/webp].freeze

  def upload_images(opf, extract_dir, opf_dir, oss_service, sanitized_title:)
    url_map = {}
    opf.xpath("//opf:item", "opf" => "http://www.idpf.org/2007/opf").each do |item|
      next unless IMAGE_MEDIA_TYPES.include?(item["media-type"])

      href = item["href"]
      img_path = extract_dir.join(opf_dir, href)
      next unless img_path.exist?

      object_key = "#{sanitized_title}/images/#{File.basename(href)}"
      oss_url = oss_service.upload_file(
        local_path: img_path,
        object_key: object_key,
        content_type: item["media-type"]
      )
      # 用相对于 OPF 目录的路径作为 key，方便后续查找
      url_map[href] = oss_url
      Rails.logger.info("[BookEpubImport] Image uploaded: #{oss_url}")
    end
    url_map
  rescue StandardError => e
    Rails.logger.warn("[BookEpubImport] Image upload failed: #{e.message}")
    {}
  end

  def replace_image_paths(xhtml_content, image_url_map, xhtml_href)
    doc = Nokogiri::HTML(xhtml_content)

    # XHTML 文件所在目录（相对于 OPF 目录）
    xhtml_dir = File.dirname(xhtml_href)

    doc.xpath("//img").each do |img|
      # 检查 src 属性（data-src 等暂不处理）
      src = img["src"]
      next if src.nil? || src.empty?
      # 跳过已经是绝对路径或 data URI 的情况
      next if src.start_with?("http://", "https://", "data:")

      # 将 XHTML 相对路径解析为相对于 OPF 目录的路径
      resolved_path = Pathname.new(xhtml_dir).join(src).cleanpath.to_s
      # 去掉可能的前导 ./
      resolved_path.delete_prefix!("./")

      oss_url = image_url_map[resolved_path]
      if oss_url
        img["src"] = oss_url
      else
        Rails.logger.warn("[BookEpubImport] Image not found in map: #{resolved_path} (original: #{src})")
      end
    end

    doc.to_html
  end
end
