# frozen_string_literal: true

FactoryBot.define do
  factory :hot_search do
    sequence(:keyword) { |n| "热门搜索词#{n}" }
    sort_order { 0 }
    is_active { true }
  end
end
