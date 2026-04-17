class CreateBookmarks < ActiveRecord::Migration[8.0]
  def change
    create_table :bookmarks, comment: "书签表" do |t|
      t.integer :user_id, null: false, comment: "用户ID"
      t.integer :book_id, null: false, comment: "图书ID"
      t.integer :chapter_id, comment: "章节ID"
      t.decimal :position, precision: 5, scale: 2, default: 0.0, comment: "位置(%)"

      t.timestamps
    end
    add_index :bookmarks, :user_id
    add_index :bookmarks, :book_id
  end
end
