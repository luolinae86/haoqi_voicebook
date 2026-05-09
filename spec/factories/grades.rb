# frozen_string_literal: true

FactoryBot.define do
  factory :grade do
    name { "三年级" }
    group_name { "小学" }
    description { "小学三年级" }
  end
end
