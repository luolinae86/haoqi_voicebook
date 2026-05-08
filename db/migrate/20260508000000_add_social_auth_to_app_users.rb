# frozen_string_literal: true

class AddSocialAuthToAppUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :app_users, :wechat_openid, :string, comment: "微信openid"
    add_column :app_users, :qq_openid, :string, comment: "QQ openid"

    add_index :app_users, :wechat_openid, unique: true
    add_index :app_users, :qq_openid, unique: true
  end
end
