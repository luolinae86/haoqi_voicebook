# frozen_string_literal: true

# 热门搜索工厂
FactoryBot.define do
  factory :hot_search do
    sequence(:keyword) { |n| "#{Faker::Book.genre}#{n}" }
    search_count { Faker::Number.between(from: 10, to: 10_000) }
    sequence(:sort_order) { |n| n }

    # 高热度
    trait :trending do
      search_count { Faker::Number.between(from: 10_000, to: 100_000) }
    end
  end
end
