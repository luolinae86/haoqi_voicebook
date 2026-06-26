# frozen_string_literal: true

# 用户分析每日预聚合表 — 定时计算 DAU/WAU/MAU/留存率，提升 Quick BI 查询性能
class CreateUserAnalyticsDaily < ActiveRecord::Migration[8.0]
  def change
    create_table :user_analytics_daily do |t|
      t.string :stat_date, null: false, comment: '日期 YYYY-MM-DD'
      t.string :channel, limit: 32, null: false, default: '', comment: '渠道（空字符串=全部）'
      t.integer :dau, default: 0, comment: '日活'
      t.integer :wau, default: 0, comment: '周活'
      t.integer :mau, default: 0, comment: '月活'
      t.integer :new_users, default: 0, comment: '新注册用户'
      t.integer :registered_users, default: 0, comment: '累计注册用户'
      t.float :retention_day_1, default: 0.0, comment: '次日留存率'
      t.float :retention_day_7, default: 0.0, comment: '7日留存率'
      t.float :retention_day_30, default: 0.0, comment: '30日留存率'
      t.integer :total_sessions, default: 0, comment: '总打开次数'

      t.index %i[stat_date channel], unique: true
    end
  end
end
