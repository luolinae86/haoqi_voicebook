# Rename uuid column to device_id in app_users table
# Note: MySQL rename_column also renames the index automatically
class RenameUuidToDeviceIdInAppUsers < ActiveRecord::Migration[8.0]
  def up
    # Column may already be renamed if this migration was partially run
    return if column_exists?(:app_users, :device_id)

    rename_column :app_users, :uuid, :device_id
  end

  def down
    return unless column_exists?(:app_users, :device_id)

    rename_column :app_users, :device_id, :uuid
  end
end
