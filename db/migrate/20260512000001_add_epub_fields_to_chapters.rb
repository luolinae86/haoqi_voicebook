# frozen_string_literal: true

class AddEpubFieldsToChapters < ActiveRecord::Migration[8.0]
  def change
    add_column :chapters, :epub_oss_key, :string, comment: "EPUB 文件 OSS 路径"
    add_column :chapters, :epub_oss_url, :string, comment: "EPUB 文件公网 URL"
    add_column :chapters, :epub_export_status, :integer, default: 0, comment: "EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败"
    add_column :chapters, :epub_export_error, :text, comment: "EPUB 导出失败原因"
    add_column :chapters, :styles_oss_url, :string, comment: "book.css 的 OSS URL"
    add_column :chapters, :nav_oss_url, :string, comment: "nav.xhtml 的 OSS URL"
  end
end
