# frozen_string_literal: true

# 会员订阅工厂
FactoryBot.define do
  factory :membership do
    association :app_user
    plan_type { :monthly }
    price { 19.90 }
    original_price { 29.90 }
    start_date { Date.current }
    end_date { 1.month.from_now.to_date }
    status { :active }

    # 待支付
    trait :pending do
      status { :pending }
    end

    # 已过期
    trait :expired do
      status { :expired }
      start_date { 2.months.ago.to_date }
      end_date { 1.month.ago.to_date }
    end

    # 已取消
    trait :cancelled do
      status { :cancelled }
    end

    # 季度会员
    trait :quarterly do
      plan_type { :quarterly }
      price { 49.90 }
      original_price { 89.70 }
      end_date { 3.months.from_now.to_date }
    end

    # 年度会员
    trait :annual do
      plan_type { :annual }
      price { 168.00 }
      original_price { 358.80 }
      end_date { 1.year.from_now.to_date }
    end
  end
end
