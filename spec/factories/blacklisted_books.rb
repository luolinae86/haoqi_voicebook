# frozen_string_literal: true

# 图书黑名单工厂
FactoryBot.define do
  factory :blacklisted_book do
    association :parental_control
    association :book
  end
end
