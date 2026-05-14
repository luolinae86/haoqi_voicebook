# frozen_string_literal: true

# 家长控制工厂
# == Schema Information
#
# Table name: parental_controls(家长管控表)
#
#  id                                 :bigint           not null, primary key
#  is_active(是否启用)                :boolean          default(TRUE), not null
#  password_digest(家长密码)          :string(255)      not null
#  phone(家长手机号)                  :string(255)
#  time_limit_minutes(时间限制(分钟)) :integer
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  app_user_id(用户ID)                :integer          not null
#
# Indexes
#
#  index_parental_controls_on_app_user_id  (app_user_id) UNIQUE
#
FactoryBot.define do
  factory :parental_control do
    association :app_user
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
