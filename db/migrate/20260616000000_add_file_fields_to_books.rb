# frozen_string_literal: true

# 生产库已有 file_url/file_type/file_name 字段但缺少对应 migration
# 补建以确保本地/测试环境同步
class AddFileFieldsToBooks < ActiveRecord::Migration[8.0]
  def up
    add_column :books, :file_url, :string, comment: "源文件URL" unless column_exists?(:books, :file_url)
    add_column :books, :file_type, :string, comment: "源文件类型 (pdf/epub)" unless column_exists?(:books, :file_type)
    add_column :books, :file_name, :string, comment: "源文件名" unless column_exists?(:books, :file_name)
  end

  def down
    remove_column :books, :file_url if column_exists?(:books, :file_url)
    remove_column :books, :file_type if column_exists?(:books, :file_type)
    remove_column :books, :file_name if column_exists?(:books, :file_name)
  end
end
