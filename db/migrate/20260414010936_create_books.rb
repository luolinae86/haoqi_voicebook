class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :books, comment: "图书表" do |t|
      t.string :title, null: false, comment: "书名"
      t.string :author, comment: "作者"
      t.string :publisher, comment: "出版社"
      t.string :cover_image, comment: "封面图片URL"
      t.text :description, comment: "内容简介"
      t.integer :content_type, null: false, default: 0, comment: "类型：0-电子书 1-有声 2-视频 3-绘本"
      t.boolean :is_free, null: false, default: false, comment: "是否免费"
      t.boolean :is_vip, null: false, default: false, comment: "是否VIP"
      t.integer :category_id, comment: "分类ID"
      t.integer :grade_id, comment: "年级ID"
      t.integer :play_count, null: false, default: 0, comment: "播放/阅读次数"
      t.integer :word_count, null: false, default: 0, comment: "字数"
      t.decimal :rating, precision: 3, scale: 1, default: 0.0, comment: "评分"
      t.integer :status, null: false, default: 0, comment: "状态：0-草稿 1-已发布 2-已下架"
      t.string :isbn, comment: "ISBN"

      t.timestamps
    end
    add_index :books, :content_type
    add_index :books, :category_id
    add_index :books, :grade_id
    add_index :books, :status
    add_index :books, :is_free
    add_index :books, :is_vip
    add_index :books, :play_count
    add_index :books, :rating
    add_index :books, :created_at
  end
end
