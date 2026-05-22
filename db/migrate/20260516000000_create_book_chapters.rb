# frozen_string_literal: true

class CreateBookChapters < ActiveRecord::Migration[7.1]
  def change
    create_table :catalogues do |t|
      t.bigint :book_id, null: false, comment: '图书ID'
      t.integer :chapter_number, null: false, comment: '章节序号'
      t.string :chapter_name, null: false, comment: '章节名称'
      t.integer :start_page_number, null: false, comment: '起始页码'
      t.boolean :is_free, default: false, null: false, comment: '是否免费'
      t.timestamps
    end

    add_index :catalogues, :book_id
    add_foreign_key :catalogues, :books
  end
end
