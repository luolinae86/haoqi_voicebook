# frozen_string_literal: true

# 阅读记录工厂
FactoryBot.define do
  factory :reading_record do
    association :user
    association :book
    association :chapter
    words_read { Faker::Number.between(from: 100, to: 5000) }
    duration_minutes { Faker::Number.between(from: 1, to: 60) }
    read_at { Faker::Time.between(from: 30.days.ago, to: Time.current) }

    # 今日阅读
    trait :today do
      read_at { Time.current }
    end

    # 长时间阅读
    trait :long_session do
      words_read { Faker::Number.between(from: 3000, to: 10_000) }
      duration_minutes { Faker::Number.between(from: 30, to: 120) }
    end
  end
end
