class AddKeywordsToPictureBookPages < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:picture_book_pages, :keywords)
      add_column :picture_book_pages, :keywords, :json, comment: '本页重点字词（人工标注，用于 book.json 的 kw 标记）'
    end
  end
end
