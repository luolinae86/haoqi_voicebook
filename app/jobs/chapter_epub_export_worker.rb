# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"
require "uri"

# EPUB 导出异步任务（章节级别）
# 流程：从章节的 content_file_url 下载 PDF → 解析导入 → 生成 EPUB → 上传到 OSS
class ChapterEpubExportWorker
  include Sidekiq::Job

  sidekiq_options queue: "export", retry: 2

  # @param args [Hash] {"chapter_id"=>Integer, "force_image_pages"=>Boolean}
  def perform(args)
    args = args.symbolize_keys
    chapter_id = args[:chapter_id]
    force_image_pages = args[:force_image_pages] == true

    chapter = Chapter.find(chapter_id)
    chapter.update!(epub_export_status: :exporting, epub_export_error: nil)

    raise ArgumentError, "章节没有 PDF 文件" unless chapter.content_file_url.present?

    pdf_url = chapter.content_file_url
    # 从完整 URL 提取 OSS object_key
    pdf_oss_key = extract_oss_key(pdf_url)
    book = chapter.book
    sanitized_title = sanitize_dir_name("#{book.name}_#{chapter.name}")
    styles_key    = "#{sanitized_title}/styles/book.css"
    nav_key       = "#{sanitized_title}/nav.xhtml"
    epub_key      = "#{sanitized_title}/#{sanitized_title}.epub"
    images_prefix = "#{sanitized_title}/images"

    Dir.mktmpdir("chapter-epub-export-#{chapter_id}") do |tmp_dir|
      tmp_path = Pathname.new(tmp_dir)

      # 1. 从 OSS 下载 PDF
      pdf_path = tmp_path.join("source.pdf")
      oss_service = AliyunOssService.new
      oss_service.download_file(object_key: pdf_oss_key, local_path: pdf_path)
      Rails.logger.info("[ChapterEpubExport] Downloaded PDF from OSS: #{pdf_oss_key}")

      # 2. 配置本地存储路径
      storage_root = tmp_path.join("storage")
      public_root = tmp_path.join("public")
      FileUtils.mkdir_p(storage_root)
      FileUtils.mkdir_p(public_root)

      # 3. PDF 导入（复用 PdfImporter，页面关联到 chapter）
      importer = Ebook::PdfImporter.new(
        book: book,
        pdf_path: pdf_path,
        source_filename: chapter.content_file_name || File.basename(pdf_oss_key),
        source_pdf_oss_key: pdf_oss_key,
        public_root: public_root,
        storage_root: storage_root,
        page_renderer: build_page_renderer(pdf_path),
        force_image_pages: force_image_pages,
        image_exporter_oss_service: oss_service,
        image_exporter_oss_prefix: images_prefix
      )
      importer.call
      Rails.logger.info("[ChapterEpubExport] PDF imported: #{book.ebook_pages.count} pages")

      # 4. 将页面关联到 chapter（PdfImporter 创建的是 book.ebook_pages）
      # 使用 chapter 的 sn 作为页码偏移，或者直接关联最新创建的页面
      book.ebook_pages.where(chapter_id: nil).update_all(chapter_id: chapter.id)
      Rails.logger.info("[ChapterEpubExport] Pages linked to chapter #{chapter_id}")

      # 5. 导出包
      export_root = tmp_path.join("export")
      Ebook::ExportPackage.new(book: book.reload, output_dir: export_root).call
      Rails.logger.info("[ChapterEpubExport] Export package created")

      # 6. 生成 EPUB（同时提取中间产物上传）
      epub_path = tmp_path.join("#{chapter.id}.epub")
      page_renderer = build_page_renderer(pdf_path)
      styles_oss_url = nil
      nav_oss_url = nil

      exporter = Ebook::EpubExporter.new(
        package_dir: export_root,
        output_path: epub_path,
        source_pdf_path: pdf_path,
        page_renderer: page_renderer
      )

      exporter.call do |epub_root|
        # 6a. 上传 book.css 到 OSS
        css_path = epub_root.join("OEBPS/styles/book.css")
        styles_oss_url = oss_service.upload_file(
          local_path: css_path,
          object_key: styles_key,
          content_type: "text/css"
        )
        Rails.logger.info("[ChapterEpubExport] Stylesheet uploaded: #{styles_oss_url}")

        # 6b. 上传 nav.xhtml 到 OSS（替换 CSS 引用为 OSS URL）
        nav_path = epub_root.join("OEBPS/nav.xhtml")
        nav_content = File.read(nav_path)
        nav_content = nav_content.gsub(
          'href="styles/book.css"',
          "href=\"#{styles_oss_url}\""
        )
        File.write(nav_path, nav_content)
        nav_oss_url = oss_service.upload_file(
          local_path: nav_path,
          object_key: nav_key,
          content_type: "application/xhtml+xml"
        )
        Rails.logger.info("[ChapterEpubExport] Navigation uploaded: #{nav_oss_url}")

        # 6c. 保存每页 XHTML 到数据库（使用 OSS CSS URL）
        book.reload
        exporter.pages.each do |page_payload|
          ebook_page = book.ebook_pages.find_by(page_number: page_payload["page_number"])
          next unless ebook_page

          xhtml = exporter.render_page_html(page_payload, root: epub_root, stylesheet_href: styles_oss_url)
          ebook_page.update!(xhtml_content: xhtml)
        end
        Rails.logger.info("[ChapterEpubExport] Page XHTML saved")

        chapter.update!(styles_oss_url: styles_oss_url, nav_oss_url: nav_oss_url)
      end

      Rails.logger.info("[ChapterEpubExport] EPUB generated: #{epub_path.size} bytes")

      # 7. 上传 EPUB 到 OSS
      epub_oss_url = oss_service.upload_file(
        local_path: epub_path,
        object_key: epub_key,
        content_type: "application/epub+zip"
      )
      Rails.logger.info("[ChapterEpubExport] EPUB uploaded to OSS: #{epub_oss_url}")

      # 8. 更新章节记录
      chapter.reload.update!(
        epub_export_status: :completed,
        epub_oss_key: epub_key,
        epub_oss_url: epub_oss_url,
        epub_export_error: nil
      )
    end

    Rails.logger.info("[ChapterEpubExport] Complete for chapter ##{chapter_id}")
  rescue StandardError => e
    chapter = Chapter.find_by(id: chapter_id)
    chapter&.update!(epub_export_status: :export_failed, epub_export_error: e.message)
    Rails.logger.error("[ChapterEpubExport] Failed for chapter ##{chapter_id}: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    raise
  end

  private

  # 从完整 URL 提取 OSS object_key
  def extract_oss_key(url)
    uri = URI.parse(url)
    # 去掉开头的 /，得到 object_key
    path = uri.path.to_s.sub(%r{\A/}, "")
    path
  end

  def sanitize_dir_name(title)
    sanitized = title.to_s.gsub(%r{[\\/:*?"<>|]}, "")
    sanitized.strip
  end

  def build_page_renderer(pdf_path)
    Ebook::PageImageRenderer.new(pdf_path: pdf_path)
  rescue StandardError => e
    Rails.logger.warn("[ChapterEpubExport] Page renderer unavailable: #{e.message}")
    nil
  end
end
