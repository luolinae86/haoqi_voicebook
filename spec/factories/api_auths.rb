# frozen_string_literal: true

# API认证工厂
FactoryBot.define do
  factory :api_auth do
    name { Faker::App.name }
    access_key_id { SecureRandom.hex(16) }
    access_key_secret { SecureRandom.hex(32) }
  end
end
