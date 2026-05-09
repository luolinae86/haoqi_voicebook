# frozen_string_literal: true

class ChangeDeviceIdLimitInAppUsers < ActiveRecord::Migration[8.0]
  def change
    change_column :app_users, :device_id, :string, limit: 64
  end
end
