# frozen_string_literal: true

# == Schema Information
#
# Table name: user_reading_daily_stats(用户阅读日统计表)
#
#  id                                         :bigint           not null, primary key
#  books_read_count(当日阅读书籍数)           :integer          default(0), not null
#  session_count(当日阅读次数)                :integer          default(0), not null
#  stat_date(统计日期 YYYY-MM-DD)             :string(255)      not null
#  total_duration_seconds(当日总阅读时长(秒)) :integer          default(0), not null
#  total_words_read(当日总阅读字数)           :integer          default(0), not null
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  app_user_id(用户ID)                        :bigint           not null
#
# Indexes
#
#  index_user_reading_daily_stats_on_app_user_id_and_stat_date  (app_user_id,stat_date) UNIQUE
#
class UserReadingDailyStats < ApplicationRecord
  self.table_name = 'user_reading_daily_stats'
  belongs_to :app_user

  scope :last_n_days, ->(days) { where(stat_date: days.days.ago.to_date.to_s..Date.today.to_s).order(stat_date: :desc) }
  scope :up_to_date, ->(date) { where('stat_date <= ?', date.to_s) }
end
