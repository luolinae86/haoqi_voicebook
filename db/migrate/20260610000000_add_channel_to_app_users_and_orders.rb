# frozen_string_literal: true

# 为 app_users 和 orders 添加渠道字段
class AddChannelToAppUsersAndOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :app_users, :channel, :string, limit: 32, comment: '注册渠道：app_store/tablet/community/koc'
    add_column :orders, :channel, :string, limit: 32, comment: '支付渠道（继承自用户）'
  end
end
