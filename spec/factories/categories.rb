# frozen_string_literal: true

# 分类工厂
FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "分类#{n}" }
    icon { Faker::Internet.url(host: "cdn.example.com", path: "/icons/#{SecureRandom.hex(4)}.png") }
    description { Faker::Lorem.sentence }
    parent_id { nil }
    sequence(:sort_order) { |n| n }

    # 子分类
    trait :with_parent do
      association :parent, factory: :category
    end
  end
end
