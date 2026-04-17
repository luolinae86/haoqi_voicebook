# frozen_string_literal: true

# 有声专辑工厂
FactoryBot.define do
  factory :audio_album do
    association :book
    narrator { Faker::Name.name }
    total_episodes { Faker::Number.between(from: 5, to: 50) }
    total_duration { Faker::Number.between(from: 1800, to: 36_000) }
    description { Faker::Lorem.paragraph(sentence_count: 2) }
  end
end
