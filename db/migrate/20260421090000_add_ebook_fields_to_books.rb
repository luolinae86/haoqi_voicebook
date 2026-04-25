# frozen_string_literal: true

class AddEbookFieldsToBooks < ActiveRecord::Migration[8.0]
  def change
    change_table :books, bulk: true do |t|
      t.integer :page_count, default: 0, null: false, comment: "电子书总页数"
      t.integer :import_status, default: 0, null: false, comment: "电子书导入状态"
      t.string :source_pdf_filename, comment: "源 PDF 文件名"
      t.string :source_pdf_path, comment: "源 PDF 存储路径"
      t.string :ebook_checksum, comment: "源 PDF 校验值"
      t.datetime :imported_at, comment: "导入完成时间"
      t.text :import_error_message, comment: "导入失败信息"
    end

    add_index :books, :import_status
  end
end
