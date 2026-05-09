class AddUuidToAppUsers < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:app_users, :uuid)
      add_column :app_users, :uuid, :string
    end

    # 为已有记录填充 uuid
    AppUser.where(uuid: nil).find_each do |user|
      user.update_columns(uuid: SecureRandom.uuid.delete("-"))
    end

    # 设置为 NOT NULL
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
