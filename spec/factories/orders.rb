# frozen_string_literal: true

# 订单工厂
FactoryBot.define do
  factory :order do
    association :user
    sequence(:order_no) { |n| "ORD#{Time.current.strftime('%Y%m%d')}#{n.to_s.rjust(6, '0')}" }
    amount { Faker::Commerce.price(range: 9.9..168.0) }
    payment_method { :wechat }
    status { :pending }
    paid_at { nil }

    # 关联会员订阅
    trait :with_membership do
      association :membership
    end

    # 已支付
    trait :paid do
      status { :paid }
      paid_at { Time.current }
    end

    # 支付失败
    trait :failed do
      status { :failed }
    end

    # 已退款
    trait :refunded do
      status { :refunded }
      paid_at { 3.days.ago }
    end

    # 支付宝支付
    trait :alipay do
      payment_method { :alipay }
    end
  end
end
