# frozen_string_literal: true

module PictureBook
  # 绘本资源包导入入口：校验 + 记资源地址 + 排 Sidekiq 任务，跟 Ebook::ImportService 一个形状。
  # 资源包是 zip（页面图 + 旁白 mp3 + 时间.txt）， hao_qi_read 先传到 OSS 再调 import。
  class ImportService
    SUPPORTED_EXTS = %w[zip].freeze

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
      PictureBookImportWorker.perform_async({ 'book_id' => @book.id, 'package_oss_key' => object_key })
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
      raise Error, '绘本只支持 zip 资源包' unless SUPPORTED_EXTS.include?(file_ext)
    end

    def update_book!
      @book.update!(
        content_file_url: @file_url,
        content_file_type: file_ext,
        content_file_name: file_name
      )
    end
  end
end
