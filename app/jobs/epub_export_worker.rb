# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"

# EPUB 导出异步任务
# 流程：从 OSS 下载 PDF → 解析导入 → 图片实时上传 OSS → 生成 EPUB → 上传 EPUB 到 OSS
# 额外：单独上传 book.css、nav.xhtml、每页 XHTML 到 OSS/DB
# 注意：Sidekiq 7 要求参数为 JSON 原生类型，使用 Hash with string keys
class EpubExportWorker
  include Sidekiq::Job

  sidekiq_options queue: "export", retry: 2

  # @param args [Hash] {"book_id"=>Integer, "pdf_oss_key"=>String, "force_image_pages"=>Boolean}
  def perform(args)
    book_id = args["book_id"]
    pdf_oss_key = args["pdf_oss_key"]
    force_image_pages = args["force_image_pages"] == true

    book = Book.find(book_id)
    book.update!(epub_export_status: :exporting, epub_export_error: nil)

    # 按书名创建 OSS 目录：{book_title}/
    sanitized_title = sanitize_dir_name(book.title)
    styles_key    = "#{sanitized_title}/styles/book.css"
    nav_key       = "#{sanitized_title}/nav.xhtml"
    epub_key      = "#{sanitized_title}/#{sanitized_title}.epub"
    images_prefix = "#{sanitized_title}/images"

    Dir.mktmpdir("epub-export-#{book_id}") do |tmp_dir|
      tmp_path = Pathname.new(tmp_dir)

      # 1. 从 OSS 下载 PDF
      pdf_path = tmp_path.join("source.pdf")
      oss_service = AliyunOssService.new
      oss_service.download_file(object_key: pdf_oss_key, local_path: pdf_path)
      Rails.logger.info("[EpubExport] Downloaded PDF from OSS: #{pdf_oss_key} (#{pdf_path.size} bytes)")

      # 2. 配置本地存储路径（临时目录）
      storage_root = tmp_path.join("storage")
      public_root = tmp_path.join("public")
      FileUtils.mkdir_p(storage_root)
      FileUtils.mkdir_p(public_root)

      # 3. PDF 导入（图片实时上传 OSS）
      importer = Ebook::PdfImporter.new(
        book: book,
        pdf_path: pdf_path,
        source_filename: File.basename(pdf_oss_key),
        source_pdf_oss_key: pdf_oss_key,
        public_root: public_root,
        storage_root: storage_root,
        page_renderer: build_page_renderer(pdf_path),
        force_image_pages: force_image_pages,
        image_exporter_oss_service: oss_service,
        image_exporter_oss_prefix: images_prefix
      )
      importer.call
      Rails.logger.info("[EpubExport] PDF imported: #{book.page_count} pages")

      # 4. 导出包
      export_root = tmp_path.join("export")
      Ebook::ExportPackage.new(book: book.reload, output_dir: export_root).call
      Rails.logger.info("[EpubExport] Export package created")

      # 5. 生成 EPUB（同时提取中间产物上传）
      epub_path = tmp_path.join("#{book.id}.epub")
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
        # 5a. 上传 book.css 到 OSS
        css_path = epub_root.join("OEBPS/styles/book.css")
        styles_oss_url = oss_service.upload_file(
          local_path: css_path,
          object_key: styles_key,
          content_type: "text/css"
        )
        Rails.logger.info("[EpubExport] Stylesheet uploaded: #{styles_oss_url}")

        # 5b. 上传 nav.xhtml 到 OSS（替换 CSS 引用为 OSS URL）
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
        Rails.logger.info("[EpubExport] Navigation uploaded: #{nav_oss_url}")

        # 5c. 保存每页 XHTML 到数据库（使用 OSS CSS URL）
        book.reload
        exporter.pages.each do |page_payload|
          ebook_page = book.ebook_pages.find_by(page_number: page_payload["page_number"])
          next unless ebook_page

          xhtml = exporter.render_page_html(page_payload, root: epub_root, stylesheet_href: styles_oss_url)
          ebook_page.update!(xhtml_content: xhtml)
        end
        Rails.logger.info("[EpubExport] Page XHTML saved: #{book.ebook_pages.where.not(xhtml_content: nil).count} pages")

        book.update!(styles_oss_url: styles_oss_url, nav_oss_url: nav_oss_url)
      end

      Rails.logger.info("[EpubExport] EPUB generated: #{epub_path.size} bytes")

      # 6. 上传 EPUB 到 OSS
      epub_oss_url = oss_service.upload_file(
        local_path: epub_path,
        object_key: epub_key,
        content_type: "application/epub+zip"
      )
      Rails.logger.info("[EpubExport] EPUB uploaded to OSS: #{epub_oss_url}")

      # 7. 更新图书记录
      book.reload.update!(
        epub_export_status: :completed,
        epub_oss_key: epub_key,
        epub_oss_url: epub_oss_url,
        epub_export_error: nil
      )
    end

    Rails.logger.info("[EpubExport] Complete for book ##{book_id}")
  rescue StandardError => e
    book = Book.find_by(id: book_id)
    book&.update!(epub_export_status: :export_failed, epub_export_error: e.message)
    Rails.logger.error("[EpubExport] Failed for book ##{book_id}: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    raise
  end

  private

  # 清理书名作为 OSS 目录名：移除特殊字符，保留中英文数字
  def sanitize_dir_name(title)
    # 移除文件名中不允许的字符
    sanitized = title.to_s.gsub(%r{[\\/:*?"<>|]}, "")
    sanitized.strip
  end

  def build_page_renderer(pdf_path)
    Ebook::PageImageRenderer.new(pdf_path: pdf_path)
  rescue StandardError => e
    Rails.logger.warn("[EpubExport] Page renderer unavailable: #{e.message}")
    nil
  end
end
