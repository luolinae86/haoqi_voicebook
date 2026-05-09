# frozen_string_literal: true

require "pathname"

module Ebook
  class LocalExportWorker
    attr_reader :book

    def initialize(pdf_path:, output_dir:, title:, book: nil, source_filename: nil, book_attributes: {},
                   export_epub: true, epub_output: nil, force_image_pages: false)
      @pdf_path = Pathname.new(pdf_path.to_s)
      @output_dir = Pathname.new(output_dir.to_s)
      @title = title
      @book = book
      @source_filename = source_filename.presence || @pdf_path.basename.to_s
      @book_attributes = book_attributes
      @export_epub = export_epub
      @epub_output = epub_output.present? ? Pathname.new(epub_output.to_s) : @output_dir.join("#{@title}.epub")
      @force_image_pages = force_image_pages == true
    end

    def call
      raise ArgumentError, "PDF 文件不存在: #{@pdf_path}" unless @pdf_path.exist?

      ensure_book!
      Ebook::PdfImporter.new(
        book: @book,
        pdf_path: @pdf_path,
        source_filename: @source_filename,
        force_image_pages: @force_image_pages
      ).call
      export_root = Ebook::ExportPackage.new(book: @book.reload, output_dir: @output_dir).call
      if @export_epub
        epub_path = Ebook::EpubExporter.new(
          package_dir: export_root,
          output_path: @epub_output,
          source_pdf_path: @pdf_path
        ).call
      end

      puts "导入完成: #{@book.name} (#{@book.page_count} 页)"
      puts "输出目录: #{export_root}"
      puts "EPUB 文件: #{epub_path}" if epub_path.present?
      export_root
    end

    private

    def ensure_book!
      return if @book.present?

      @book = Book.find_or_initialize_by(name: @title)
      @book.assign_attributes(@book_attributes.merge(status: :published, content_type: :ebook))
      @book.name = @title
      @book.save! if @book.new_record? || @book.changed?
    end
  end
end
