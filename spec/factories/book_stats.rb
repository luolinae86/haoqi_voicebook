# frozen_string_literal: true

# == Schema Information
#
# Table name: book_stats(图书统计表)
#
#  id                                     :bigint           not null, primary key
#  completed_count(完读人数)              :integer          default(0), not null
#  completion_rate(完读率)                :float(24)        default(0.0), not null
#  monthly_readers(近30天阅读人数)        :integer          default(0), not null
#  monthly_reads(近30天阅读次数)          :integer          default(0), not null
#  total_duration_seconds(总阅读时长(秒)) :integer          default(0), not null
#  total_readers(总阅读人数(去重))        :integer          default(0), not null
#  total_reads(总阅读次数)                :integer          default(0), not null
#  total_words_read(总阅读字数)           :integer          default(0), not null
#  weekly_readers(近7天阅读人数)          :integer          default(0), not null
#  weekly_reads(近7天阅读次数)            :integer          default(0), not null
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  book_id(图书ID)                        :bigint           not null
#
# Indexes
#
#  index_book_stats_on_book_id          (book_id) UNIQUE
#  index_book_stats_on_monthly_readers  (monthly_readers)
#  index_book_stats_on_weekly_readers   (weekly_readers)
#
FactoryBot.define do
  factory :book_stats do
    association :book
    total_readers { 0 }
    total_reads { 0 }
    total_duration_seconds { 0 }
    total_words_read { 0 }
    completed_count { 0 }
    completion_rate { 0.0 }
    weekly_readers { 0 }
    weekly_reads { 0 }
    monthly_readers { 0 }
    monthly_reads { 0 }
  end
end
