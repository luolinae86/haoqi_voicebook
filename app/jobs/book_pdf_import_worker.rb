# frozen_string_literal: true

require "pathname"
require "tmpdir"
require "fileutils"
require "uri"

# PDF 导入异步任务（按 Book 级别）
# 流程：从 book.content_file_url 下载 PDF → 按强制图片模式导入 → 生成图片页
class BookPdfImportWorker
  include Sidekiq::Job

  sidekiq_options queue: "import", retry: 2

  # @param args [Hash] {"book_id"=>Integer, "pdf_oss_key"=>String, "force_image_pages"=>Boolean}
  def perform(args)
    args = args.symbolize_keys
    book_id = args[:book_id]
    pdf_oss_key = args[:pdf_oss_key]

    book = Book.find(book_id)
    return if book.import_status == 'ready'

    book.update!(import_status: :processing, import_error_message: nil)

    Dir.mktmpdir("book-pdf-import-#{book_id}") do |tmp_dir|
      tmp_path = Pathname.new(tmp_dir)

      # 1. 从 OSS 下载 PDF
      pdf_path = tmp_path.join("source.pdf")
      oss_service = AliyunOssService.new
      oss_service.download_file(object_key: pdf_oss_key, local_path: pdf_path)
      Rails.logger.info("[BookPdfImport] Downloaded PDF from OSS: #{pdf_oss_key}")

      # 2. 配置本地存储路径
      storage_root = tmp_path.join("storage")
      public_root = tmp_path.join("public")
      FileUtils.mkdir_p(storage_root)
      FileUtils.mkdir_p(public_root)

      sanitized_title = sanitize_dir_name(book.name)
      images_prefix = "#{sanitized_title}/images"

      # 3. PDF 导入（强制图片模式）
      importer = Ebook::PdfImporter.new(
        book: book,
        pdf_path: pdf_path,
        source_filename: File.basename(pdf_oss_key),
        source_pdf_oss_key: pdf_oss_key,
        public_root: public_root,
        storage_root: storage_root,
        page_renderer: build_page_renderer(pdf_path),
        force_image_pages: true, # PDF 始终按图片模式导入
        image_exporter_oss_service: oss_service,
        image_exporter_oss_prefix: images_prefix
      )
      importer.call
      Rails.logger.info("[BookPdfImport] PDF imported: #{book.ebook_pages.count} pages")
    end

    Rails.logger.info("[BookPdfImport] Complete for book ##{book_id}")
  rescue StandardError => e
    book = Book.find_by(id: book_id)
    book&.update!(import_status: :failed, import_error_message: e.message)
    Rails.logger.error("[BookPdfImport] Failed for book ##{book_id}: #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    raise
  end

  private

  def sanitize_dir_name(title)
    sanitized = title.to_s.gsub(%r{[\\/:*?"<>|]}, "")
    sanitized.strip
  end

  def build_page_renderer(pdf_path)
    Ebook::PageImageRenderer.new(pdf_path: pdf_path)
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::Error => e
    Rails.logger.warn("[BookPdfImport] Page renderer unavailable: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.warn("[BookPdfImport] Page renderer unavailable: #{e.class}: #{e.message}")
    nil
  end
end
