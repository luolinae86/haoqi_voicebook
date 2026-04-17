# frozen_string_literal: true

# 推荐条目工厂
FactoryBot.define do
  factory :recommendation_item do
    association :recommendation
    association :book
    sequence(:sort_order) { |n| n }
  end
end
