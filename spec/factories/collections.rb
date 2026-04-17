# frozen_string_literal: true

# 书单合集工厂
FactoryBot.define do
  factory :collection do
    sequence(:title) { |n| "精选书单#{n}" }
    description { Faker::Lorem.paragraph(sentence_count: 2) }
    cover_image { Faker::Internet.url(host: "cdn.example.com", path: "/collections/#{SecureRandom.hex(4)}.jpg") }
    collection_type { "topic" }
    sequence(:sort_order) { |n| n }

    # 关联目标年级
    trait :with_target_grade do
      association :target_grade, factory: :grade
    end
  end
end
