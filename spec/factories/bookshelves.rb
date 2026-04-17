# frozen_string_literal: true

# 书架工厂
FactoryBot.define do
  factory :bookshelf do
    association :user
    association :book
    reading_progress { 0.0 }
    last_read_at { nil }

    # 阅读中
    trait :reading do
      reading_progress { Faker::Number.decimal(l_digits: 2, r_digits: 1) }
      last_read_at { Faker::Time.between(from: 7.days.ago, to: Time.current) }
    end

    # 已读完
    trait :finished do
      reading_progress { 100.0 }
      last_read_at { Faker::Time.between(from: 30.days.ago, to: Time.current) }
    end

    # 关联最后阅读章节
    trait :with_last_chapter do
      association :last_read_chapter, factory: :chapter
    end
  end
end
