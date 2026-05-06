# frozen_string_literal: true

# 书签工厂
FactoryBot.define do
  factory :bookmark do
    association :app_user
    association :book
    association :chapter
    position { Faker::Number.decimal(l_digits: 2, r_digits: 1) }
  end
end
