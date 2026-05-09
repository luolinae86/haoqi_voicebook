# frozen_string_literal: true

FactoryBot.define do
  factory :content_group do
    association :recommend
    name { "内容分组#{Faker::Number.number(digits: 2)}" }
    group_type { "multi_images" }
    sn { 0 }
  end
end
