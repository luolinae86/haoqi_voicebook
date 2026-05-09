class AddUuidToAppUsers < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:app_users, :uuid)
      add_column :app_users, :uuid, :string, null: false, default: ""
    end
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
