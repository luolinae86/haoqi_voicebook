class CreateReadingRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :reading_records, comment: "阅读记录表" do |t|
      t.integer :user_id, null: false, comment: "用户ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.integer :chapter_id, comment: "章节ID"
      t.integer :words_read, null: false, default: 0, comment: "阅读字数"
      t.integer :duration_minutes, null: false, default: 0, comment: "阅读时长(分钟)"
      t.datetime :read_at, comment: "阅读时间"

      t.timestamps
    end
    add_index :reading_records, :user_id
    add_index :reading_records, :book_id
    add_index :reading_records, :read_at
  end
end
