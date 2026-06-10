# frozen_string_literal: true

# 用户分析每日预聚合模型
# == Schema Information
#
# Table name: user_analytics_daily
#
#  id                             :bigint           not null, primary key
#  channel(渠道（NULL=全部）)     :string(32)
#  dau(日活)                      :integer          default(0)
#  mau(月活)                      :integer          default(0)
#  new_users(新注册用户)          :integer          default(0)
#  registered_users(累计注册用户) :integer          default(0)
#  retention_day_1(次日留存率)    :float(24)        default(0.0)
#  retention_day_30(30日留存率)   :float(24)        default(0.0)
#  retention_day_7(7日留存率)     :float(24)        default(0.0)
#  stat_date(日期 YYYY-MM-DD)     :string(255)      not null
#  total_sessions(总打开次数)     :integer          default(0)
#  wau(周活)                      :integer          default(0)
#
# Indexes
#
#  index_user_analytics_daily_on_stat_date_and_channel  (stat_date,channel) UNIQUE
#
class UserAnalyticsDaily < ApplicationRecord
  self.table_name = 'user_analytics_daily'
  scope :by_date, ->(date) { where(stat_date: date.to_s) }
  scope :by_date_range, ->(start_date, end_date) { where(stat_date: start_date.to_s..end_date.to_s) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :global, -> { where(channel: nil) }

  # 创建或更新某日期的聚合数据
  def self.upsert_daily!(date:, dau: 0, wau: 0, mau: 0, new_users: 0,
                         registered_users: 0, retention_day_1: 0.0,
                         retention_day_7: 0.0, retention_day_30: 0.0,
                         total_sessions: 0, channel: nil)
    stat_date = date.to_s
    record = find_or_initialize_by(stat_date: stat_date, channel: channel)
    record.assign_attributes(
      dau: dau, wau: wau, mau: mau,
      new_users: new_users, registered_users: registered_users,
      retention_day_1: retention_day_1,
      retention_day_7: retention_day_7,
      retention_day_30: retention_day_30,
      total_sessions: total_sessions
    )
    record.save!
    record
  end
end
