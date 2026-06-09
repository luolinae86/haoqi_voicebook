# frozen_string_literal: true

# 用户活跃日志表 — 记录用户打开 APP 的行为，用于计算 DAU/WAU/MAU/留存率
class CreateUserActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :user_activity_logs do |t|
      t.bigint :app_user_id, null: false, comment: '用户ID'
      t.string :channel, limit: 32, comment: '渠道（冗余，便于按渠道查）'
      t.string :activity_type, limit: 32, null: false, comment: '类型：app_open（打开APP）'
      t.string :stat_date, null: false, comment: '日期 YYYY-MM-DD'
      t.datetime :created_at, null: false

      t.index %i[app_user_id stat_date activity_type], unique: true
      t.index :stat_date
      t.index :channel
    end
  end
end
