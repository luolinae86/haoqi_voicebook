# frozen_string_literal: true

# == Schema Information
#
# Table name: user_reading_daily_stats
#
#  app_user_id         :bigint           not null, comment: '用户ID'
#  stat_date           :string           not null, comment: '统计日期 YYYY-MM-DD'
#  session_count       :integer          not null, default(0), comment: '当日阅读次数'
#  total_duration_seconds:integer       not null, default(0), comment: '当日总阅读时长(秒)'
#  total_words_read    :integer          not null, default(0), comment: '当日总阅读字数'
#  books_read_count    :integer          not null, default(0), comment: '当日阅读书籍数'
#
class UserReadingDailyStats < ApplicationRecord
  self.table_name = 'user_reading_daily_stats'
  belongs_to :app_user

  scope :last_n_days, ->(days) { where(stat_date: days.days.ago.to_date.to_s..Date.today.to_s).order(stat_date: :desc) }
  scope :up_to_date, ->(date) { where('stat_date <= ?', date.to_s) }
end
