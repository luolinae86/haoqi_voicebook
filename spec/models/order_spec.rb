# frozen_string_literal: true

require "rails_helper"

RSpec.describe Order, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:membership).optional }
  end

  # 验证测试
  describe "validations" do
    subject { create(:order) }

    it { should validate_presence_of(:order_no) }
    it { should validate_uniqueness_of(:order_no).case_insensitive }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
  end

  # 枚举测试
  describe "enums" do
    it { should define_enum_for(:payment_method).with_values(alipay: 0, wechat: 1) }
    it { should define_enum_for(:status).with_values(pending: 0, paid: 1, failed: 2, refunded: 3) }
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
end
