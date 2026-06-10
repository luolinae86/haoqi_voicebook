# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_progress(阅读进度表)
#
#  id                                           :bigint           not null, primary key
#  completed(是否已读完)                        :boolean          default(FALSE), not null
#  completed_at(完读时间)                       :datetime
#  last_page_number(最新阅读到的页码)           :integer          default(1), not null
#  last_read_at(最近阅读时间)                   :datetime         not null
#  session_count(阅读次数)                      :integer          default(0), not null
#  total_duration_seconds(本书累计阅读时长(秒)) :integer          default(0), not null
#  total_words_read(本书累计阅读字数)           :integer          default(0), not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  app_user_id(用户ID)                          :bigint           not null
#  book_id(图书ID)                              :bigint           not null
#
# Indexes
#
#  index_reading_progress_on_app_user_id_and_book_id  (app_user_id,book_id) UNIQUE
#  index_reading_progress_on_book_id                  (book_id)
#
FactoryBot.define do
  factory :reading_progress do
    association :app_user
    association :book
    last_page_number { 1 }
    total_words_read { 0 }
    total_duration_seconds { 0 }
    session_count { 0 }
    completed { false }
    last_read_at { Time.current }
  end
end
