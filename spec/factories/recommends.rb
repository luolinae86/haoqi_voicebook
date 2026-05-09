# frozen_string_literal: true

FactoryBot.define do
  factory :recommend do
    association :grade
    name { "推荐内容#{Faker::Number.number(digits: 2)}" }
    sn { 0 }
    status { true }
  end
end
