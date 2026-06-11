# frozen_string_literal: true

class AddExpiresAtAndDeviceTypeToAppUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :app_users, :expires_at, :datetime, comment: '账户过期时间，nil 表示永久有效'
    add_column :app_users, :device_type, :string, comment: '设备类型 phone/pad'
  end
end
