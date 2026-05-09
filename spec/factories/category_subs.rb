# frozen_string_literal: true

FactoryBot.define do
  factory :category_sub do
    association :category
    name { "子类#{Faker::Number.number(digits: 2)}" }
    sn { 0 }
  end
end
