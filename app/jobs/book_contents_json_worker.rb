# frozen_string_literal: true

# 从 book_contents（haoqi_read 写入的图片页）异步生成 book.json。
class BookContentsJsonWorker
  include Sidekiq::Job

  sidekiq_options queue: "import", retry: 2

  def perform(args)
    args = args.symbolize_keys
    book = Book.find(args[:book_id])

    PictureBook::BookContentsJsonGenerator.new(book: book).call

    Rails.logger.info("[BookContentsJson] Done for book ##{args[:book_id]}")
  rescue StandardError => e
    book = Book.find_by(id: args[:book_id])
    book&.update!(import_status: :failed, import_error_message: e.message)
    Rails.logger.error("[BookContentsJson] Failed for book ##{args[:book_id]}: #{e.class}: #{e.message}")
    raise
  end
end
