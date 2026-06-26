# frozen_string_literal: true

# == Schema Information
#
# Table name: daily_channel_stats
#
class DailyChannelStat < ApplicationRecord
  scope :by_date, ->(date) { where(stat_date: date) }
  scope :by_channel, ->(channel) { where(channel: channel) }
  scope :platform_summary, -> { where(channel: '') }
end
