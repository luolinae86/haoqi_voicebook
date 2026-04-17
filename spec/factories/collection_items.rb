# frozen_string_literal: true

# 书单条目工厂
FactoryBot.define do
  factory :collection_item do
    association :collection
    association :book
    sequence(:sort_order) { |n| n }
  end
end
