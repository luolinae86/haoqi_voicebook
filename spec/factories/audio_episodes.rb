# frozen_string_literal: true

# 有声单集工厂
FactoryBot.define do
  factory :audio_episode do
    association :audio_album
    sequence(:title) { |n| "第#{n}集 #{Faker::Lorem.sentence(word_count: 3)}" }
    audio_url { Faker::Internet.url(host: "cdn.example.com", path: "/audio/#{SecureRandom.hex(8)}.mp3") }
    duration { Faker::Number.between(from: 180, to: 1800) }
    sequence(:sort_order) { |n| n }
    is_free { false }
    is_vip { false }
    play_count { 0 }

    # 免费单集
    trait :free do
      is_free { true }
    end

    # VIP专享
    trait :vip_only do
      is_vip { true }
    end

    # 热门单集
    trait :popular do
      play_count { Faker::Number.between(from: 500, to: 50_000) }
    end
  end
end
