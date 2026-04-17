# frozen_string_literal: true

# 章节工厂
FactoryBot.define do
  factory :chapter do
    association :book
    sequence(:title) { |n| "第#{n}章 #{Faker::Lorem.sentence(word_count: 3)}" }
    content { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    sequence(:sort_order) { |n| n }
    is_free { false }
    is_vip { false }
    word_count { Faker::Number.between(from: 500, to: 5000) }

    # 免费章节
    trait :free do
      is_free { true }
    end

    # VIP专享章节
    trait :vip_only do
      is_vip { true }
    end
  end
end
