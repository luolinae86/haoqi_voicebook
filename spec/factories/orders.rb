# frozen_string_literal: true

# 订单工厂
# == Schema Information
#
# Table name: orders(订单表)
#
#  id                                              :bigint           not null, primary key
#  amount(金额)                                    :decimal(10, 2)   not null
#  channel(支付渠道（继承自用户）)                 :string(32)
#  order_no(订单号)                                :string(255)      not null
#  paid_at(支付时间)                               :datetime
#  payment_method(支付方式：0-支付宝 1-微信)       :integer          default("alipay"), not null
#  status(状态：0-待支付 1-已支付 2-失败 3-已退款) :integer          default("pending"), not null
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  app_user_id(用户ID)                             :integer          not null
#  membership_id(会员ID)                           :integer
#
# Indexes
#
#  index_orders_on_app_user_id    (app_user_id)
#  index_orders_on_membership_id  (membership_id)
#  index_orders_on_order_no       (order_no) UNIQUE
#  index_orders_on_status         (status)
#
FactoryBot.define do
  factory :order do
    association :app_user
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
