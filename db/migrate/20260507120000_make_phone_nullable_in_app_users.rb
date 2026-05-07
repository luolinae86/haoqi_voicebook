# frozen_string_literal: true

class MakePhoneNullableInAppUsers < ActiveRecord::Migration[8.0]
  def up
    change_column_null :app_users, :phone, true
    # 清除已有的空字符串或无效 phone
    AppUser.where(phone: "").update_all(phone: nil)
  end

  def down
    # 回填 nil 的 phone 为临时值
    AppUser.where(phone: nil).update_all(phone: "00000000000")
    change_column_null :app_users, :phone, false
  end
end
