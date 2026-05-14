# frozen_string_literal: true

# 会员订阅工厂
# == Schema Information
#
# Table name: memberships(会员表)
#
#  id                                              :bigint           not null, primary key
#  end_date(结束日期)                              :date             not null
#  original_price(原价)                            :decimal(10, 2)
#  plan_type(套餐：0-月度 1-季度 2-年度)           :integer          default("monthly"), not null
#  price(实付价格)                                 :decimal(10, 2)   not null
#  start_date(开始日期)                            :date             not null
#  status(状态：0-待支付 1-有效 2-已过期 3-已取消) :integer          default("pending"), not null
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  app_user_id(用户ID)                             :integer          not null
#
# Indexes
#
#  index_memberships_on_app_user_id  (app_user_id)
#  index_memberships_on_end_date     (end_date)
#  index_memberships_on_status       (status)
#
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
