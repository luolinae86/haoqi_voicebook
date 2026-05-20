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
require "rails_helper"

RSpec.describe Order, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:app_user) }
    it { is_expected.to belong_to(:membership).optional }
  end

  # 验证测试
  describe "validations" do
    subject { create(:order) }

    it { is_expected.to validate_presence_of(:order_no) }
    it { is_expected.to validate_uniqueness_of(:order_no).case_insensitive }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
  end

  # 枚举测试
  describe "enums" do
    it { is_expected.to define_enum_for(:payment_method).with_values(alipay: 0, wechat: 1) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, paid: 1, failed: 2, refunded: 3) }
  end

  # 回调测试
  describe "callbacks" do
    describe "before_validation on create" do
      it "自动生成订单号" do
        order = build(:order, order_no: nil)
        order.valid?
        expect(order.order_no).to be_present
        expect(order.order_no).to start_with("VB")
      end

      it "不覆盖已有的订单号" do
        order = build(:order, order_no: "CUSTOM123")
        order.valid?
        expect(order.order_no).to eq("CUSTOM123")
      end
    end
  end

  # 实例方法测试
  describe "#mark_paid!" do
    it "将订单标记为已支付" do
      order = create(:order, status: :pending)
      order.mark_paid!

      expect(order.reload.status).to eq("paid")
      expect(order.paid_at).to be_present
    end
  end

  # 作用域测试
  describe "scopes" do
    describe ".pending" do
      it "只返回待支付订单" do
        pending_order = create(:order, status: :pending)
        create(:order, status: :paid)
        create(:order, status: :failed)

        expect(Order.pending).to include(pending_order)
        expect(Order.pending.size).to eq(1)
      end
    end

    describe ".paid" do
      it "只返回已支付订单" do
        create(:order, status: :pending)
        paid_order = create(:order, status: :paid)
        create(:order, status: :failed)

        expect(Order.paid).to include(paid_order)
        expect(Order.paid.size).to eq(1)
      end
    end
  end
end
