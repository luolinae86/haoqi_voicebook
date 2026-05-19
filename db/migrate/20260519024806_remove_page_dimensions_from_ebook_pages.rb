class RemovePageDimensionsFromEbookPages < ActiveRecord::Migration[7.1]
  def change
    remove_column :ebook_pages, :page_width, :decimal
    remove_column :ebook_pages, :page_height, :decimal
  end
end
