class CreateChapters < ActiveRecord::Migration[8.0]
  def change
    create_table :chapters, comment: "章节表" do |t|
      t.integer :book_id, null: false, comment: "图书ID"
      t.string :title, null: false, comment: "章节标题"
      t.integer :sort_order, null: false, default: 0, comment: "排序"
      t.text :content, comment: "章节内容"
      t.boolean :is_free, null: false, default: false, comment: "是否免费"
      t.boolean :is_vip, null: false, default: false, comment: "是否VIP"
      t.integer :word_count, null: false, default: 0, comment: "字数"

      t.timestamps
    end
    add_index :chapters, :book_id
    add_index :chapters, [:book_id, :sort_order]
  end
end
