class CreateBookshelves < ActiveRecord::Migration[8.0]
  def change
    create_table :bookshelves, comment: "书架表" do |t|
      t.integer :user_id, null: false, comment: "用户ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.decimal :reading_progress, precision: 5, scale: 2, default: 0.0, comment: "阅读进度(%)"
      t.integer :last_read_chapter_id, comment: "最后阅读章节ID"
      t.datetime :last_read_at, comment: "最后阅读时间"

      t.timestamps
    end
    add_index :bookshelves, :user_id
    add_index :bookshelves, :book_id
    add_index :bookshelves, [:user_id, :book_id], unique: true
  end
end
