# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_sessions(阅读记录表)
#
#  id                                 :bigint           not null, primary key
#  duration_seconds(本次阅读时长(秒)) :integer          default(0), not null
#  ended_at(结束阅读时间)             :datetime
#  page_number(阅读到的页码)          :integer          default(1), not null
#  read_date(阅读日期 YYYY-MM-DD)     :string(255)      not null
#  started_at(开始阅读时间)           :datetime         not null
#  word_count(本次阅读字数)           :integer          default(0), not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  app_user_id(用户ID)                :bigint           not null
#  book_id(图书ID)                    :bigint           not null
#
# Indexes
#
#  index_reading_sessions_on_app_user_id_and_book_id    (app_user_id,book_id)
#  index_reading_sessions_on_app_user_id_and_read_date  (app_user_id,read_date)
#  index_reading_sessions_on_book_id                    (book_id)
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
