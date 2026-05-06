# frozen_string_literal: true

# 重命名 users 表为 app_users，并重命名对应索引
class RenameUsersToAppUsers < ActiveRecord::Migration[8.0]
  def change
    rename_table :users, :app_users

    rename_index :app_users, "index_users_on_grade_id", "index_app_users_on_grade_id"
    rename_index :app_users, "index_users_on_is_vip", "index_app_users_on_is_vip"
    rename_index :app_users, "index_users_on_phone", "index_app_users_on_phone"
    rename_index :app_users, "index_users_on_uuid", "index_app_users_on_uuid"
  end
end
