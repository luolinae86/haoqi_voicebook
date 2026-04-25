# frozen_string_literal: true

class CreateEbookPages < ActiveRecord::Migration[8.0]
  def change
    create_table :ebook_pages, comment: "电子书页面表" do |t|
      t.references :book, null: false, foreign_key: true, comment: "图书ID"
      t.integer :page_number, null: false, comment: "页码"
      t.decimal :page_width, precision: 8, scale: 2, null: false, comment: "页面宽度(pt)"
      t.decimal :page_height, precision: 8, scale: 2, null: false, comment: "页面高度(pt)"
      t.text :plain_text, comment: "页面纯文本"
      t.json :rich_content, null: false, comment: "页面富文本块"
      t.integer :word_count, default: 0, null: false, comment: "字数"
      t.integer :block_count, default: 0, null: false, comment: "块数量"
      t.integer :image_count, default: 0, null: false, comment: "图片数量"

      t.timestamps
    end

    add_index :ebook_pages, %i[book_id page_number], unique: true
  end
end
