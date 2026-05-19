# frozen_string_literal: true

# == Schema Information
#
# Table name: book_stats
#
#  book_id              :bigint           not null, comment: '图书ID'
#  total_readers        :integer          not null, default(0), comment: '总阅读人数(去重)'
#  total_reads          :integer          not null, default(0), comment: '总阅读次数'
#  total_duration_seconds :integer       not null, default(0), comment: '总阅读时长(秒)'
#  total_words_read     :integer          not null, default(0), comment: '总阅读字数'
#  completed_count      :integer          not null, default(0), comment: '完读人数'
#  completion_rate      :float            not null, default(0.0), comment: '完读率'
#  weekly_readers       :integer          not null, default(0), comment: '近7天阅读人数'
#  weekly_reads         :integer          not null, default(0), comment: '近7天阅读次数'
#  monthly_readers      :integer          not null, default(0), comment: '近30天阅读人数'
#  monthly_reads        :integer          not null, default(0), comment: '近30天阅读次数'
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
