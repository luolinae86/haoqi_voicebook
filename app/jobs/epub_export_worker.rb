# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"

# EPUB 导出异步任务
# 流程：从 OSS 下载 PDF → 解析导入 → 图片实时上传 OSS → 生成 EPUB → 上传 EPUB 到 OSS
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
        public_root: public_root,
        storage_root: storage_root,
        page_renderer: build_page_renderer(pdf_path),
        force_image_pages: force_image_pages,
        image_exporter_oss_service: oss_service,
        image_exporter_oss_prefix: "epub-assets/pages/#{book.id}"
      )
      importer.call
      Rails.logger.info("[EpubExport] PDF imported: #{book.page_count} pages")

      # 4. 导出包
      export_root = tmp_path.join("export")
      Ebook::ExportPackage.new(book: book.reload, output_dir: export_root).call
      Rails.logger.info("[EpubExport] Export package created")

      # 5. 生成 EPUB
      epub_path = tmp_path.join("#{book.id}.epub")
      Ebook::EpubExporter.new(
        package_dir: export_root,
        output_path: epub_path,
        source_pdf_path: pdf_path,
        page_renderer: build_page_renderer(pdf_path)
      ).call
      Rails.logger.info("[EpubExport] EPUB generated: #{epub_path.size} bytes")

      # 6. 上传 EPUB 到 OSS
      epub_oss_key = "epub-assets/books/#{book.id}/book.epub"
      epub_oss_url = oss_service.upload_file(
        local_path: epub_path,
        object_key: epub_oss_key,
        content_type: "application/epub+zip"
      )
      Rails.logger.info("[EpubExport] EPUB uploaded to OSS: #{epub_oss_url}")

      # 7. 更新图书记录
      book.update!(
        epub_export_status: :completed,
        epub_oss_key: epub_oss_key,
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

  def build_page_renderer(pdf_path)
    Ebook::PageImageRenderer.new(pdf_path: pdf_path)
  rescue StandardError => e
    Rails.logger.warn("[EpubExport] Page renderer unavailable: #{e.message}")
    nil
  end
end
