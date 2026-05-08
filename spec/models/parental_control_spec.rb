# frozen_string_literal: true

require "rails_helper"

RSpec.describe ParentalControl, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:app_user) }
    it { is_expected.to have_many(:blacklisted_books).dependent(:destroy) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:parental_control) }

    it { is_expected.to validate_uniqueness_of(:app_user_id) }
    it { is_expected.to validate_numericality_of(:time_limit_minutes).is_greater_than(0).allow_nil }
  end

  # 密码加密测试
  describe "has_secure_password" do
    it "密码正确时验证通过" do
      pc = create(:parental_control, password: "123456")
      expect(pc.authenticate("123456")).to eq(pc)
    end

    it "密码错误时验证失败" do
      pc = create(:parental_control, password: "123456")
      expect(pc.authenticate("wrong")).to be false
    end
  end

  # 常量测试
  describe "TIME_LIMITS" do
    it "包含预设的时间限制选项" do
      expect(ParentalControl::TIME_LIMITS).to eq([30, 60, 90, nil])
    end
  end
end
