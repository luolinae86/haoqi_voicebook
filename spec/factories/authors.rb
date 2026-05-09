# frozen_string_literal: true

FactoryBot.define do
  factory :author do
    name { Faker::Book.author }
    head_img { Faker::Internet.url(host: "cdn.example.com", path: "/avatars/#{SecureRandom.hex(4)}.jpg") }
  end
end
