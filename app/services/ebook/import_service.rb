# frozen_string_literal: true

module Ebook
  class ImportService
    SUPPORTED_EXTS = %w[pdf epub].freeze

    class Error < StandardError; end

    def initialize(book:, file_url:)
      @book = book
      @file_url = file_url
    end

    def call
      validate_url!
      validate_type!
      if @book.import_status == 'processing'
        raise Error, '该书正在导入中，请稍后再试'
      elsif @book.import_status == 'ready'
        raise Error, '该书已完成导入，如需重新导入请先清除导入状态'
      end

      update_book!
      enqueue_worker!
    end

    private

    def uri
      @uri ||= URI.parse(@file_url)
    end

    def file_ext
      @file_ext ||= File.extname(uri.path).downcase.delete('.')
    end

    def object_key
      @object_key ||= uri.path.sub(%r{\A/}, '')
    end

    def file_name
      @file_name ||= File.basename(uri.path)
    end

    def validate_url!
      raise Error, '无效的 OSS 文件 URL' if object_key.blank?
    end

    def validate_type!
      raise Error, '仅支持 PDF 和 EPUB 文件' unless SUPPORTED_EXTS.include?(file_ext)
    end

    def update_book!
      @book.update!(
        content_file_url: @file_url,
        content_file_type: file_ext,
        content_file_name: file_name
      )
    end

    def enqueue_worker!
      worker_class = file_ext == 'pdf' ? BookPdfImportWorker : BookEpubImportWorker
      worker_class.perform_async({
                                   'book_id' => @book.id,
                                   "#{file_ext}_oss_key" => object_key
                                 })
    end
  end
end
