# frozen_string_literal: true

namespace :book do
  desc '重新生成指定绘本的 book.json（用法：rake book:regenerate[2]）'
  task :regenerate, [:book_id] => :environment do |_t, args|
    book_id = args[:book_id]
    abort "请提供 book_id" unless book_id

    book = Book.find(book_id)
    puts "开始生成 Book ##{book_id}: #{book.name}..."

    generator = PictureBook::BookContentsJsonGenerator.new(book: book)
    result = generator.call

    puts "生成完成，共 #{result[:pages]} 页"
  end
end
