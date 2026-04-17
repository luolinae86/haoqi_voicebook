# frozen_string_literal: true

# 推荐工厂
FactoryBot.define do
  factory :recommendation do
    sequence(:title) { |n| "每日推荐#{n}" }
    description { Faker::Lorem.paragraph(sentence_count: 2) }
    recommendation_type { "featured" }
    sequence(:sort_order) { |n| n }

    # 关联目标年级
    trait :with_target_grade do
      association :target_grade, factory: :grade
    end

    # 分级推荐
    trait :graded do
      recommendation_type { "graded" }
    end

    # 热门推荐
    trait :trending do
      recommendation_type { "trending" }
    end
  end
end
