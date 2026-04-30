class AddEpubExportFieldsToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :epub_oss_key, :string, comment: "EPUB 文件 OSS 路径"
    add_column :books, :epub_oss_url, :string, comment: "EPUB 文件公网 URL"
    add_column :books, :epub_export_status, :integer, default: 0, comment: "EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败"
    add_column :books, :epub_export_error, :text, comment: "EPUB 导出失败原因"
  end
end
