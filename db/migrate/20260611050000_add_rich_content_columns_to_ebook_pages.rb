# frozen_string_literal: true

class AddRichContentColumnsToEbookPages < ActiveRecord::Migration[8.0]
  def change
    add_column :ebook_pages, :page_width, :float
    add_column :ebook_pages, :page_height, :float
    add_column :ebook_pages, :plain_text, :text
    add_column :ebook_pages, :rich_content, :json
    add_column :ebook_pages, :block_count, :integer, default: 0
    add_column :ebook_pages, :image_count, :integer, default: 0
  end
end
