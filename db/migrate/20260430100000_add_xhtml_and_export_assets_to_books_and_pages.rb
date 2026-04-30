# frozen_string_literal: true

class AddXhtmlAndExportAssetsToBooksAndPages < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :styles_oss_url, :string, comment: "book.css 的 OSS URL"
    add_column :books, :nav_oss_url, :string, comment: "nav.xhtml 的 OSS URL"
    add_column :ebook_pages, :xhtml_content, :text, comment: "页面 XHTML 内容"
  end
end
