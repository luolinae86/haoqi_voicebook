class AddUuidToAppUsers < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:app_users, :uuid)
      add_column :app_users, :uuid, :string
    end

    # 为已有记录填充 uuid（包括 nil 和空字符串）
    # 逐条更新以避免在内存中加载所有记录
    execute "UPDATE app_users SET uuid = REPLACE(UUID(), '-',) WHERE uuid IS NULL OR uuid = ''"

    # 确保 NOT NULL 约束
    change_column_null :app_users, :uuid, false

    unless index_exists?(:app_users, :uuid)
      add_index :app_users, :uuid, unique: true
    end
  end

  def down
    if index_exists?(:app_users, :uuid)
      remove_index :app_users, :uuid
    end
    if column_exists?(:app_users, :uuid)
      remove_column :app_users, :uuid
    end
  end
end
