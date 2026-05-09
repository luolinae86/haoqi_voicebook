# frozen_string_literal: true

FactoryBot.define do
  factory :supplier do
    name { Faker::Company.name }
  end
end
