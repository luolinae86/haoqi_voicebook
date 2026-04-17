# frozen_string_literal: true

# 短信验证码工厂
FactoryBot.define do
  factory :sms_verification do
    phone { "1#{rand(3..9)}#{Faker::Number.number(digits: 9)}" }
    code { Faker::Number.number(digits: 4).to_s.rjust(4, "0") }
    expires_at { 5.minutes.from_now }
    verified { false }

    # 已验证
    trait :verified do
      verified { true }
    end

    # 已过期
    trait :expired do
      expires_at { 1.minute.ago }
    end

    # 已过期且已验证
    trait :expired_and_verified do
      verified { true }
      expires_at { 1.minute.ago }
    end
  end
end
