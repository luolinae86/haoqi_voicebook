# frozen_string_literal: true

# 短信验证码工厂
# == Schema Information
#
# Table name: sms_verifications(短信验证码表)
#
#  id                   :bigint           not null, primary key
#  code(验证码)         :string(255)      not null
#  expires_at(过期时间) :datetime         not null
#  phone(手机号)        :string(255)      not null
#  verified(是否已验证) :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_sms_verifications_on_expires_at      (expires_at)
#  index_sms_verifications_on_phone_and_code  (phone,code)
#
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
