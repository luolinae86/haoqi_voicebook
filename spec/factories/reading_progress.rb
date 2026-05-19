# frozen_string_literal: true

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
