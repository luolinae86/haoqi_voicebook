# frozen_string_literal: true

# 用户活跃日志模型 — 记录用户打开 APP 的行为
class UserActivityLog < ApplicationRecord
  belongs_to :app_user

  scope :by_date, ->(date) { where(stat_date: date.to_s) }
  scope :by_date_range, ->(start_date, end_date) { where(stat_date: start_date.to_s..end_date.to_s) }
  scope :by_channel, ->(channel) { where(channel: channel) }

  # 同一用户同一天只记录一条 app_open
  def self.log_app_open(app_user, channel: nil)
    find_or_create_by(
      app_user_id: app_user.id,
      stat_date: Time.zone.today.to_s,
      activity_type: 'app_open'
    ) do |log|
      log.channel = channel.presence || app_user.channel
    end
  end
end
