# frozen_string_literal: true

FactoryBot.define do
  factory :compilation do
    name { "合辑#{Faker::Number.number(digits: 3)}" }
    publisher { "测试出版社" }
    total_count { 0 }
  end
end
