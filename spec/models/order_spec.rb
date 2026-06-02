# frozen_string_literal: true

# == Schema Information
#
# Table name: orders(订单表)
#
#  id                                              :bigint           not null, primary key
#  amount(金额)                                    :decimal(10, 2)   not null
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
require 'rails_helper'

RSpec.describe Order, type: :model do
  # 关联测试
  describe 'associations' do
    it { is_expected.to belong_to(:app_user) }
    it { is_expected.to belong_to(:membership).optional }
  end

  # 验证测试
  describe 'validations' do
    subject { create(:order) }

    it { is_expected.to validate_presence_of(:order_no) }
    it { is_expected.to validate_uniqueness_of(:order_no).case_insensitive }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
  end

  # 枚举测试
  describe 'enums' do
    it { is_expected.to define_enum_for(:payment_method).with_values(alipay: 0, wechat: 1) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, paid: 1, failed: 2, refunded: 3) }
  end

  # 回调测试
  describe 'callbacks' do
    describe 'before_validation on create' do
      it '自动生成订单号' do
        order = build(:order, order_no: nil)
        order.valid?
        expect(order.order_no).to be_present
        expect(order.order_no).to start_with('VB')
      end

      it '不覆盖已有的订单号' do
        order = build(:order, order_no: 'CUSTOM123')
        order.valid?
        expect(order.order_no).to eq('CUSTOM123')
      end
    end
  end

  # 实例方法测试
  describe '#mark_paid!' do
    it '将订单标记为已支付' do
      order = create(:order, status: :pending)
      order.mark_paid!

      expect(order.reload.status).to eq('paid')
      expect(order.paid_at).to be_present
    end
  end

  describe '#activate_membership!' do
    it '首次购买时激活会员' do
      user = create(:app_user, is_vip: false, vip_expires_at: nil)
      membership = create(:membership, app_user: user, status: :pending)
      order = create(:order, app_user: user, membership: membership, status: :pending)

      order.activate_membership!

      expect(membership.reload.status).to eq('active')
      expect(user.reload.is_vip).to be true
      expect(user.vip_expires_at).to be_present
      expect(user.vip_expires_at.to_date).to be >= 1.month.from_now.to_date
    end

    it '已购买过月度会员的用户再次购买月度会员，VIP 时间顺延 1 个月' do
      user = create(:app_user, is_vip: true, vip_expires_at: 1.month.from_now.to_date.end_of_day)
      membership = create(:membership, app_user: user, status: :pending)
      order = create(:order, app_user: user, membership: membership, status: :pending)

      old_expires = user.vip_expires_at
      order.activate_membership!

      # 应该在原过期时间基础上增加约 1 个月
      expect(user.reload.vip_expires_at.to_date).to be > old_expires.to_date
      # 新过期时间应该约等于旧过期时间 + 1 个月（误差 1 天内）
      expected_days = (old_expires + 1.month).to_date - old_expires.to_date
      actual_days = user.reload.vip_expires_at.to_date - old_expires.to_date
      expect(actual_days).to be_within(1).of(expected_days)
    end

    it '已购买月度会员的用户再次购买年度会员，VIP 时间顺延 1 年' do
      Timecop.freeze(Time.zone.parse('2026-06-01 12:00:00')) do
        user = create(:app_user, is_vip: true, vip_expires_at: Time.zone.parse('2026-07-01 23:59:59'))
        membership = create(:membership, app_user: user, plan_type: :annual, status: :pending)
        order = create(:order, app_user: user, membership: membership, status: :pending)

        order.activate_membership!

        # 年度会员应在现有过期时间基础上增加 1 年
        expect(user.reload.vip_expires_at.to_date).to be >= (Time.zone.parse('2026-07-01') + 1.year)
      end
    end

    it 'VIP 已过期的用户再次购买，重新计算过期时间' do
      user = create(:app_user, is_vip: true, vip_expires_at: 1.month.ago.to_date.end_of_day)
      membership = create(:membership, app_user: user, status: :pending)
      order = create(:order, app_user: user, membership: membership, status: :pending)

      order.activate_membership!

      # 过期时间应从当前日期开始计算，不叠加
      expect(user.reload.vip_expires_at.to_date).to be < 1.month.from_now.to_date + 1.day
      expect(user.reload.vip_expires_at.to_date).to be >= Date.current
    end
  end

  # 作用域测试
  describe 'scopes' do
    describe '.pending' do
      it '只返回待支付订单' do
        pending_order = create(:order, status: :pending)
        create(:order, status: :paid)
        create(:order, status: :failed)

        expect(Order.pending).to include(pending_order)
        expect(Order.pending.size).to eq(1)
      end
    end

    describe '.paid' do
      it '只返回已支付订单' do
        create(:order, status: :pending)
        paid_order = create(:order, status: :paid)
        create(:order, status: :failed)

        expect(Order.paid).to include(paid_order)
        expect(Order.paid.size).to eq(1)
      end
    end
  end
end
