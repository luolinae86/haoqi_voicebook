# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    name { Faker::Book.genre }
    level { 1 }
    sn { 0 }
    active { true }
  end
end
