# frozen_string_literal: true

# 排行榜条目工厂
FactoryBot.define do
  factory :ranking_item do
    association :ranking
    association :book
    sequence(:rank) { |n| n }
    score { Faker::Number.decimal(l_digits: 2, r_digits: 1) }

    # 榜首
    trait :top do
      rank { 1 }
      score { Faker::Number.between(from: 95.0, to: 100.0).round(1) }
    end
  end
end
