# frozen_string_literal: true

class AddFilePathsToChapters < ActiveRecord::Migration[8.0]
  def up
    add_column :chapters, :ld_file_path, :string, comment: '低清文件路径' unless column_exists?(:chapters, :ld_file_path)
    add_column :chapters, :hd_file_path, :string, comment: '高清文件路径' unless column_exists?(:chapters, :hd_file_path)
    add_column :chapters, :sd_file_path, :string, comment: '标清文件路径' unless column_exists?(:chapters, :sd_file_path)
    add_column :chapters, :snap_file_path, :string, comment: '截图文件路径' unless column_exists?(:chapters, :snap_file_path)
  end

  def down
    remove_column :chapters, :snap_file_path if column_exists?(:chapters, :snap_file_path)
    remove_column :chapters, :sd_file_path if column_exists?(:chapters, :sd_file_path)
    remove_column :chapters, :hd_file_path if column_exists?(:chapters, :hd_file_path)
    remove_column :chapters, :ld_file_path if column_exists?(:chapters, :ld_file_path)
  end
end
