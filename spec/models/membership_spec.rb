# frozen_string_literal: true

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
require "rails_helper"

RSpec.describe Membership, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:app_user) }
    it { is_expected.to have_many(:orders).dependent(:nullify) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:plan_type) }
    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:original_price).is_greater_than(0).allow_nil }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
  end

  # 枚举测试
  describe "enums" do
    it { is_expected.to define_enum_for(:plan_type).with_values(monthly: 0, quarterly: 1, annual: 2) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, active: 1, expired: 2, cancelled: 3) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".active_memberships" do
      it "只返回状态为 active 且未过期的会员" do
        active = create(:membership, status: :active, end_date: 1.month.from_now)
        expired_active = create(:membership, status: :active, end_date: 1.day.ago)
        pending = create(:membership, status: :pending, end_date: 1.month.from_now)

        expect(Membership.active_memberships).to include(active)
        expect(Membership.active_memberships).not_to include(expired_active)
        expect(Membership.active_memberships).not_to include(pending)
      end
    end
  end

  # 实例方法测试
  describe "#active?" do
    it "会员有效时返回 true" do
      membership = build(:membership, status: :active, end_date: 1.month.from_now)
      expect(membership.active?).to be true
    end

    it "会员已过期时返回 false" do
      membership = build(:membership, status: :active, end_date: 1.day.ago)
      expect(membership.active?).to be false
    end

    it "会员状态非 active 时返回 false" do
      membership = build(:membership, status: :pending, end_date: 1.month.from_now)
      expect(membership.active?).to be false
    end
  end

  describe "#duration_days" do
    it "计算会员套餐天数" do
      membership = build(:membership, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 1, 31))
      expect(membership.duration_days).to eq(30)
    end
  end
end
