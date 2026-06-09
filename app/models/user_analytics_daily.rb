# frozen_string_literal: true

# 用户分析每日预聚合模型
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
