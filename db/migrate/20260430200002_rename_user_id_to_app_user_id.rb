# frozen_string_literal: true

# 重命名所有外键表的 user_id 为 app_user_id
# MySQL 会在 rename_column 时自动重命名对应索引
class RenameUserIdToAppUserId < ActiveRecord::Migration[8.0]
  def change
    rename_column :bookshelves, :user_id, :app_user_id
    rename_column :memberships, :user_id, :app_user_id
    rename_column :orders, :user_id, :app_user_id
    rename_column :parental_controls, :user_id, :app_user_id
    rename_column :reading_records, :user_id, :app_user_id
  end
end
