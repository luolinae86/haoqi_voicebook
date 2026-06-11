# frozen_string_literal: true

# == Schema Information
#
# Table name: parental_controls(家长管控表)
#
#  id                                 :bigint           not null, primary key
#  is_active(是否启用)                :boolean          default(TRUE), not null
#  password_digest(家长密码)          :string(255)      not null
#  phone(家长手机号)                  :string(255)
#  time_limit_minutes(时间限制(分钟)) :integer
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  app_user_id(用户ID)                :integer          not null
#
# Indexes
#
#  index_parental_controls_on_app_user_id  (app_user_id) UNIQUE
#
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
      expect(ParentalControl::TIME_LIMITS).to eq([0, 30, 60, 90])
    end
  end
end
