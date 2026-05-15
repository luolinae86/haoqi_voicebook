# frozen_string_literal: true

# 移除 Chapter 模型，将电子书内容直接关联到 Book
# 1. Book 增加 content_file_url/type/name（原属于 Chapter）
# 2. ebook_pages 移除 chapter_id，增加 image_url，移除 PDF 不再使用的字段
# 3. 删除 chapters 表
class RemoveChaptersAndRestructureEbookPages < ActiveRecord::Migration[7.1]
  def up
    # 1. Book 增加内容文件字段
    unless column_exists?(:books, :content_file_url)
      add_column :books, :content_file_url, :string, comment: "电子书内容文件URL"
    end
    unless column_exists?(:books, :content_file_type)
      add_column :books, :content_file_type, :string, comment: "内容文件类型 (epub/pdf)"
    end
    unless column_exists?(:books, :content_file_name)
      add_column :books, :content_file_name, :string, comment: "内容文件名"
    end

    # 2. ebook_pages 移除 chapter_id FK
    if foreign_key_exists?(:ebook_pages, :chapters)
      remove_foreign_key :ebook_pages, :chapters
    end

    # 3. ebook_pages 增加 image_url（PDF 页面用）
    unless column_exists?(:ebook_pages, :image_url)
      add_column :ebook_pages, :image_url, :string, comment: "页面图片URL（PDF导入）"
    end

    # 3b. recommends 增加 color 字段
    unless column_exists?(:recommends, :color)
      add_column :recommends, :color, :string, limit: 16, default: "", comment: "颜色"
    end

    # 4. 移除不再需要的字段
    remove_column :ebook_pages, :chapter_id if column_exists?(:ebook_pages, :chapter_id)
    remove_column :ebook_pages, :plain_text if column_exists?(:ebook_pages, :plain_text)
    remove_column :ebook_pages, :rich_content if column_exists?(:ebook_pages, :rich_content)
    remove_column :ebook_pages, :block_count if column_exists?(:ebook_pages, :block_count)
    remove_column :ebook_pages, :image_count if column_exists?(:ebook_pages, :image_count)

    # 4b. 移除 page_width 和 page_height
    remove_column :ebook_pages, :page_width if column_exists?(:ebook_pages, :page_width)
    remove_column :ebook_pages, :page_height if column_exists?(:ebook_pages, :page_height)

    # 5. 删除 chapters 表
    drop_table :chapters, if_exists: true
  end

  def down
    # 恢复 chapters 表（简化版本，不含数据）
    create_table :chapters, if_not_exists: true do |t|
      t.bigint "book_id", null: false
      t.string "name", null: false
      t.string "cover_image_url"
      t.string "content_file_url"
      t.string "content_file_name"
      t.string "content_file_type"
      t.boolean "is_free", default: false
      t.boolean "is_published", default: false
      t.integer "sn", default: 0
      t.string "epub_oss_key"
      t.string "epub_oss_url"
      t.integer "epub_export_status", default: 0
      t.text "epub_export_error"
      t.string "styles_oss_url"
      t.string "nav_oss_url"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["book_id"], name: "index_chapters_on_book_id"
    end

    # 恢复 ebook_pages 字段
    add_column :ebook_pages, :chapter_id, :bigint unless column_exists?(:ebook_pages, :chapter_id)
    add_column :ebook_pages, :plain_text, :text unless column_exists?(:ebook_pages, :plain_text)
    add_column :ebook_pages, :rich_content, :json unless column_exists?(:ebook_pages, :rich_content)
    add_column :ebook_pages, :block_count, :integer, default: 0 unless column_exists?(:ebook_pages, :block_count)
    add_column :ebook_pages, :image_count, :integer, default: 0 unless column_exists?(:ebook_pages, :image_count)
    add_column :ebook_pages, :page_width, :decimal, precision: 8, scale: 2 unless column_exists?(:ebook_pages, :page_width)
    add_column :ebook_pages, :page_height, :decimal, precision: 8, scale: 2 unless column_exists?(:ebook_pages, :page_height)
    remove_column :ebook_pages, :image_url if column_exists?(:ebook_pages, :image_url)

    # 恢复 FK
    unless foreign_key_exists?(:ebook_pages, :chapters)
      add_foreign_key :ebook_pages, :chapters
    end

    # 移除 Book 新增字段
    remove_column :books, :content_file_url if column_exists?(:books, :content_file_url)
    remove_column :books, :content_file_type if column_exists?(:books, :content_file_type)
    remove_column :books, :content_file_name if column_exists?(:books, :content_file_name)
    remove_column :recommends, :color if column_exists?(:recommends, :color)
  end
end
