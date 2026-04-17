# frozen_string_literal: true

# 家长控制工厂
FactoryBot.define do
  factory :parental_control do
    association :user
    password { "123456" }
    time_limit_minutes { 60 }
    is_active { true }
    phone { "1#{rand(3..9)}#{Faker::Number.number(digits: 9)}" }

    # 已停用
    trait :inactive do
      is_active { false }
    end

    # 无时间限制
    trait :unlimited do
      time_limit_minutes { nil }
    end

    # 严格模式（短时间限制）
    trait :strict do
      time_limit_minutes { 30 }
    end
  end
end
