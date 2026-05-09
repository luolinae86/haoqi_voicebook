# frozen_string_literal: true

FactoryBot.define do
  factory :book_level do
    name { "Level #{Faker::Number.between(from: 1, to: 10)}" }
    sn { Faker::Number.between(from: 1, to: 100) }
  end
end
