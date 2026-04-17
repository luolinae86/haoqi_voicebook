# frozen_string_literal: true

# 年级工厂
FactoryBot.define do
  factory :grade do
    sequence(:name) { |n| "#{n}年级" }
    sequence(:level) { |n| n }
    description { Faker::Lorem.sentence }
    sequence(:sort_order) { |n| n }
  end
end
