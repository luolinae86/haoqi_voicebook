# frozen_string_literal: true

# 阅读等级工厂
FactoryBot.define do
  factory :reading_level do
    sequence(:name) { |n| "阅读等级#{n}" }
    sequence(:level) { |n| n }
    description { Faker::Lorem.sentence }

    # 幼儿级别
    trait :preschool do
      name { "幼儿级" }
    end

    # 小学低年级
    trait :primary_junior do
      name { "小学低年级" }
    end

    # 小学高年级
    trait :primary_senior do
      name { "小学高年级" }
    end
  end
end
