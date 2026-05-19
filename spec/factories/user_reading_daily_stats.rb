# frozen_string_literal: true

FactoryBot.define do
  factory :user_reading_daily_stats do
    association :app_user
    stat_date { Time.current.strftime('%Y-%m-%d') }
    session_count { 0 }
    total_duration_seconds { 0 }
    total_words_read { 0 }
    books_read_count { 0 }
  end
end
