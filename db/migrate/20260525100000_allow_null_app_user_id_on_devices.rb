# frozen_string_literal: true

class AllowNullAppUserIdOnDevices < ActiveRecord::Migration[8.0]
  def up
    change_column_null :devices, :app_user_id, true
  end

  def down
    # 先清理未绑定的 device，再改回 not null
    Device.where(app_user_id: nil).destroy_all
    change_column_null :devices, :app_user_id, false
  end
end
