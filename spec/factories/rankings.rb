# frozen_string_literal: true

# 排行榜工厂
FactoryBot.define do
  factory :ranking do
    sequence(:name) { |n| "排行榜#{n}" }
    ranking_type { :hot }
    description { Faker::Lorem.sentence }

    # 评分榜
    trait :rating do
      ranking_type { :high_score }
      name { "评分排行榜" }
    end

    # 新书榜
    trait :new_arrival do
      ranking_type { :new_arrival }
      name { "新书排行榜" }
    end

    # 获奖榜
    trait :award do
      ranking_type { :award }
      name { "获奖图书榜" }
    end

    # 经典榜
    trait :classic do
      ranking_type { :classic }
      name { "经典图书榜" }
    end
  end
end
