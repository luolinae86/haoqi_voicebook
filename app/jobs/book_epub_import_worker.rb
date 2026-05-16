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

      # 7. 导入每页 XHTML 和章节
      page_number = 1
      total_word_count = 0
      sanitized_title = sanitize_dir_name(book.name)
      chapter_number = 0
      non_toc_pages = 0

      Book.transaction do
        book.ebook_pages.delete_all
        book.book_chapters.delete_all

        spine_refs.each do |href|
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

          xhtml_content = File.read(xhtml_path)
          word_count = extract_word_count(xhtml_content)

          book.ebook_pages.create!(
            page_number: has_toc ? page_number : 0,
            xhtml_content: xhtml_content,
            word_count: word_count
          )

          total_word_count += word_count
          page_number += 1 if has_toc
          non_toc_pages += 1 unless has_toc
        end

        book.update!(
          content_type: :ebook,
          word_count: total_word_count,
          page_count: page_number - 1 + non_toc_pages,
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
    book&.update!(import_status: :failed, import_error_message: e.message)
    Rails.logger.error("[BookEpubImport] Failed for book ##{book_id}: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    raise
  end

  private

  def sanitize_dir_name(title)
    sanitized = title.to_s.gsub(%r{[\\/:*?"<>|]}, "")
    sanitized.strip
  end

  def extract_toc(opf, extract_dir, opf_dir)
    toc_entries = []

    # 尝试从 nav.xhtml 提取 TOC
    nav_item = opf.xpath("//opf:item[@properties='nav']", "opf" => "http://www.idpf.org/2007/opf").first
    if nav_item
      nav_path = extract_dir.join(opf_dir, nav_item["href"])
      if nav_path.exist?
        nav = Nokogiri::XML(File.read(nav_path))
        nav.xpath("//nav:nav//nav:a", "nav" => "http://www.w3.org/1999/xhtml").each do |link|
          href = link["href"]
          href = href.split("#").first if href.include?("#")  # 去掉锚点
          toc_entries << { title: link.text.strip, href: href }
        end
        return toc_entries
      end
    end

    # 回退到 toc.ncx
    ncx_item = opf.xpath("//opf:item[contains(@media-type, 'x-dtbncx')]", "opf" => "http://www.idpf.org/2007/opf").first
    if ncx_item
      ncx_path = extract_dir.join(opf_dir, ncx_item["href"])
      if ncx_path.exist?
        ncx = Nokogiri::XML(File.read(ncx_path))
        extract_ncx_navpoints(ncx.xpath("//ncx:navMap", "ncx" => "http://www.daisy.org/z3986/2005/ncx/").first, toc_entries)
      end
    end

    toc_entries
  end

  def extract_ncx_navpoints(parent_node, toc_entries)
    return unless parent_node
    ns = { "ncx" => "http://www.daisy.org/z3986/2005/ncx/" }
    parent_node.xpath("./ncx:navPoint", ns).each do |nav_point|
      title = nav_point.at_xpath("ncx:navLabel/ncx:text", ns)&.text
      src = nav_point.at_xpath("ncx:content", ns)&.[]("src")
      href = src.to_s.split("#").first if src
      toc_entries << { title: title.to_s.strip, href: href } if title.present?
      # 递归提取子 navPoint
      extract_ncx_navpoints(nav_point, toc_entries)
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
end
