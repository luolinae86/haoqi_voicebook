# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_sessions
#
#  app_user_id      :bigint           not null, comment: '用户ID'
#  book_id          :bigint           not null, comment: '图书ID'
#  page_number      :integer          not null, default(1), comment: '阅读到的页码'
#  word_count       :integer          not null, default(0), comment: '本次阅读字数'
#  duration_seconds :integer          not null, default(0), comment: '本次阅读时长(秒)'
#  started_at       :datetime         not null, comment: '开始阅读时间'
#  ended_at         :datetime         comment: '结束阅读时间'
#  read_date        :string           not null, comment: '阅读日期 YYYY-MM-DD'
#
FactoryBot.define do
  factory :reading_session do
    association :app_user
    association :book
    page_number { 1 }
    word_count { 500 }
    duration_seconds { 300 }
    started_at { Time.current }
    read_date { Date.today.to_s }
  end
end
