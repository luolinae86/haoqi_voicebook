class AddVoicebookFieldsToBooksAndRecreateEbookPages < ActiveRecord::Migration[8.0]
  def up
    # ---- Add voicebook-specific columns to books ----
    unless column_exists?(:books, :content_type)
      add_column :books, :content_type, :integer, default: 0, null: false, comment: "类型：0-电子书 1-有声 2-视频 3-绘本"
    end
    unless column_exists?(:books, :is_free)
      add_column :books, :is_free, :boolean, default: false, null: false, comment: "是否免费"
    end
    unless column_exists?(:books, :is_vip)
      add_column :books, :is_vip, :boolean, default: false, null: false, comment: "是否VIP"
    end
    unless column_exists?(:books, :grade_id)
      add_column :books, :grade_id, :bigint, comment: "年级ID"
    end
    unless column_exists?(:books, :play_count)
      add_column :books, :play_count, :integer, default: 0, null: false, comment: "播放/阅读次数"
    end
    unless column_exists?(:books, :word_count)
      add_column :books, :word_count, :integer, default: 0, null: false, comment: "字数"
    end
    unless column_exists?(:books, :rating)
      add_column :books, :rating, :decimal, precision: 3, scale: 1, default: "0.0", comment: "评分"
    end
    unless column_exists?(:books, :status)
      add_column :books, :status, :integer, default: 0, null: false, comment: "状态：0-草稿 1-已发布 2-已下架"
    end
    unless column_exists?(:books, :isbn)
      add_column :books, :isbn, :string, comment: "ISBN"
    end
    unless column_exists?(:books, :page_count)
      add_column :books, :page_count, :integer, default: 0, null: false, comment: "电子书总页数"
    end
    unless column_exists?(:books, :import_status)
      add_column :books, :import_status, :integer, default: 0, null: false, comment: "电子书导入状态"
    end
    unless column_exists?(:books, :source_pdf_filename)
      add_column :books, :source_pdf_filename, :string, comment: "源 PDF 文件名"
    end
    unless column_exists?(:books, :source_pdf_path)
      add_column :books, :source_pdf_path, :string, comment: "源 PDF 存储路径"
    end
    unless column_exists?(:books, :ebook_checksum)
      add_column :books, :ebook_checksum, :string, comment: "源 PDF 校验值"
    end
    unless column_exists?(:books, :imported_at)
      add_column :books, :imported_at, :datetime, comment: "导入完成时间"
    end
    unless column_exists?(:books, :import_error_message)
      add_column :books, :import_error_message, :text, comment: "导入失败信息"
    end
    unless column_exists?(:books, :epub_oss_key)
      add_column :books, :epub_oss_key, :string, comment: "EPUB 文件 OSS 路径"
    end
    unless column_exists?(:books, :epub_oss_url)
      add_column :books, :epub_oss_url, :string, comment: "EPUB 文件公网 URL"
    end
    unless column_exists?(:books, :epub_export_status)
      add_column :books, :epub_export_status, :integer, default: 0, comment: "EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败"
    end
    unless column_exists?(:books, :epub_export_error)
      add_column :books, :epub_export_error, :text, comment: "EPUB 导出失败原因"
    end
    unless column_exists?(:books, :styles_oss_url)
      add_column :books, :styles_oss_url, :string, comment: "book.css 的 OSS URL"
    end
    unless column_exists?(:books, :nav_oss_url)
      add_column :books, :nav_oss_url, :string, comment: "nav.xhtml 的 OSS URL"
    end

    add_index :books, :import_status unless index_exists?(:books, :import_status)
    add_index :books, :status unless index_exists?(:books, :status)

    # ---- Recreate ebook_pages table ----
    unless table_exists?(:ebook_pages)
      create_table :ebook_pages, comment: "电子书页面表" do |t|
        t.bigint :book_id, null: false, comment: "图书ID"
        t.integer :page_number, null: false, comment: "页码"
        t.decimal :page_width, precision: 8, scale: 2, null: false, comment: "页面宽度(pt)"
        t.decimal :page_height, precision: 8, scale: 2, null: false, comment: "页面高度(pt)"
        t.text :plain_text, comment: "页面纯文本"
        t.json :rich_content, null: false, comment: "页面富文本块"
        t.integer :word_count, default: 0, null: false, comment: "字数"
        t.integer :block_count, default: 0, null: false, comment: "块数量"
        t.integer :image_count, default: 0, null: false, comment: "图片数量"
        t.text :xhtml_content, comment: "页面 XHTML 内容"
        t.timestamps
      end
      add_index :ebook_pages, [:book_id, :page_number], unique: true, name: "index_ebook_pages_on_book_id_and_page_number"
      add_index :ebook_pages, :book_id
      add_foreign_key :ebook_pages, :books
    end
  end

  def down
    remove_foreign_key :ebook_pages, :books, if_exists: true
    drop_table :ebook_pages, if_exists: true

    columns_to_remove = %i[
      content_type is_free is_vip grade_id play_count word_count rating status isbn
      page_count import_status source_pdf_filename source_pdf_path ebook_checksum
      imported_at import_error_message epub_oss_key epub_oss_url epub_export_status
      epub_export_error styles_oss_url nav_oss_url
    ]
    columns_to_remove.each do |col|
      remove_column :books, col if column_exists?(:books, col)
    end
    remove_index :books, :import_status, if_exists: true
    remove_index :books, :status, if_exists: true
  end
end
