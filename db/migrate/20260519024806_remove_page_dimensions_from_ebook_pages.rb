class RemovePageDimensionsFromEbookPages < ActiveRecord::Migration[7.1]
  def up
    remove_column :ebook_pages, :page_width, :decimal if column_exists?(:ebook_pages, :page_width)
    remove_column :ebook_pages, :page_height, :decimal if column_exists?(:ebook_pages, :page_height)
  end

  def down
    add_column :ebook_pages, :page_width, :decimal, precision: 8, scale: 2, null: false, default: 0
    add_column :ebook_pages, :page_height, :decimal, precision: 8, scale: 2, null: false, default: 0
  end
end
