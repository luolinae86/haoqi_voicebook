# frozen_string_literal: true

class AddWechatNicknameToAppUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :app_users, :wechat_nickname, :string, comment: '微信昵称'
  end
end
