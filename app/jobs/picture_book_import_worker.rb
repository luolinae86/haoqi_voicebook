# frozen_string_literal: true

require 'tmpdir'

# 绘本导入异步任务：从 OSS 取资源包 zip → PictureBook::Pipeline 生成 book.json/dict.json。
# OCR/ASR 的原始返回都在流程里逐页落库，所以 Sidekiq 重试不会把同一页再认一遍。
class PictureBookImportWorker
  include Sidekiq::Job

  sidekiq_options queue: 'import', retry: 2

  # @param args [Hash] {"book_id"=>Integer, "package_oss_key"=>String}
  def perform(args)
    args = args.symbolize_keys
    book_id = args[:book_id]
    book = Book.find(book_id)
    return if book.import_status == 'ready'

    book.update!(import_status: :processing, import_error_message: nil)

    Dir.mktmpdir("picture-book-#{book_id}") do |tmp|
      zip_path = File.join(tmp, 'package.zip')
      oss = AliyunOssService.new
      oss.download_file(object_key: args[:package_oss_key], local_path: zip_path)

      package = PictureBook::Package.open(zip_path, tmpdir: tmp)
      Rails.logger.info("[PictureBookImport] book ##{book_id} #{package.summary}")

      stats = PictureBook::Pipeline.new(book: book, package: package, workdir: tmp).call
      Rails.logger.info("[PictureBookImport] book ##{book_id} 完成 #{stats.inspect}")
    end
  rescue StandardError => e
    Rails.logger.error("[PictureBookImport] book ##{book_id} 失败 #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(20).join("\n"))
    book&.update!(import_status: :failed, import_error_message: e.message)
    raise
  end
end
