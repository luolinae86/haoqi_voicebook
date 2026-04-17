# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:orders).dependent(:nullify) }
  end

  # 验证测试
  describe "validations" do
    it { should validate_presence_of(:plan_type) }
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
    it { should validate_numericality_of(:original_price).is_greater_than(0).allow_nil }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
  end

  # 枚举测试
  describe "enums" do
    it { should define_enum_for(:plan_type).with_values(monthly: 0, quarterly: 1, annual: 2) }
    it { should define_enum_for(:status).with_values(pending: 0, active: 1, expired: 2, cancelled: 3) }
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
