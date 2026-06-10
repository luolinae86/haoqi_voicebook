# frozen_string_literal: true

# 用户活跃日志模型 — 记录用户打开 APP 的行为
# == Schema Information
#
# Table name: user_activity_logs
#
#  id                                       :bigint           not null, primary key
#  activity_type(类型：app_open（打开APP）) :string(32)       not null
#  channel(渠道（冗余，便于按渠道查）)      :string(32)
#  stat_date(日期 YYYY-MM-DD)               :string(255)      not null
#  created_at                               :datetime         not null
#  app_user_id(用户ID)                      :bigint           not null
#
# Indexes
#
#  idx_on_app_user_id_stat_date_activity_type_16ce7f2edf  (app_user_id,stat_date,activity_type) UNIQUE
#  index_user_activity_logs_on_channel                    (channel)
#  index_user_activity_logs_on_stat_date                  (stat_date)
#
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
