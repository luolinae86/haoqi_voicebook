class ChangeXhtmlContentToMediumtext < ActiveRecord::Migration[8.0]
  def change
    change_column :ebook_pages, :xhtml_content, :mediumtext
  end
end
