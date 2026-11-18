# frozen_string_literal: true

namespace :book do
  desc '重新生成指定绘本的 book.json（用法：rake book:regenerate[2] 或 rake book:regenerate[2,true] 强制重新 ASR）'
  task :regenerate, [:book_id, :force] => :environment do |_t, args|
    book_id = args[:book_id]
    force = args[:force].to_s == 'true'
    abort "请提供 book_id" unless book_id

    book = Book.find(book_id)

    if force
      puts "清除 ASR 缓存..."
      book.update!(asr_raw: nil)
    end

    puts "开始生成 Book ##{book_id}: #{book.name}..."

    generator = PictureBook::BookContentsJsonGenerator.new(book: book)
    result = generator.call

    puts "生成完成，共 #{result[:pages]} 页"
  end
end
