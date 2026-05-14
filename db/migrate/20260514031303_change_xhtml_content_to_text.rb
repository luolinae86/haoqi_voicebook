class ChangeXhtmlContentToText < ActiveRecord::Migration[8.0]
  def change
    change_column :ebook_pages, :xhtml_content, :text
  end
end
