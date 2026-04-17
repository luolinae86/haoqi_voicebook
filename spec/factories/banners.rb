# frozen_string_literal: true

# 横幅广告工厂
FactoryBot.define do
  factory :banner do
    sequence(:title) { |n| "Banner #{n}" }
    image_url { Faker::Internet.url(host: "cdn.example.com", path: "/banners/#{SecureRandom.hex(4)}.jpg") }
    link_url { Faker::Internet.url }
    link_type { "book" }
    sequence(:sort_order) { |n| n }
    is_active { true }
    starts_at { Time.current }
    ends_at { 30.days.from_now }

    # 已停用
    trait :inactive do
      is_active { false }
    end

    # 已过期
    trait :expired do
      starts_at { 60.days.ago }
      ends_at { 30.days.ago }
    end

    # 即将上线
    trait :upcoming do
      starts_at { 1.day.from_now }
      ends_at { 31.days.from_now }
    end
  end
end
