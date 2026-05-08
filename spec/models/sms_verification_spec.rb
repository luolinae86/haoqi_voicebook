# frozen_string_literal: true

require "rails_helper"

RSpec.describe SmsVerification, type: :model do
  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:phone) }
    it { is_expected.to allow_value("13800138000").for(:phone) }
    it { is_expected.not_to allow_value("12345678901").for(:phone) }
    it { is_expected.not_to allow_value("1380013800").for(:phone) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_length_of(:code).is_equal_to(4) }
    it { is_expected.to validate_presence_of(:expires_at) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".valid_codes" do
      it "只返回未验证且未过期的验证码" do
        valid = create(:sms_verification, verified: false, expires_at: 5.minutes.from_now)
        expired = create(:sms_verification, verified: false, expires_at: 1.minute.ago)
        used = create(:sms_verification, verified: true, expires_at: 5.minutes.from_now)

        expect(SmsVerification.valid_codes).to include(valid)
        expect(SmsVerification.valid_codes).not_to include(expired)
        expect(SmsVerification.valid_codes).not_to include(used)
      end
    end
  end

  # 实例方法测试
  describe "#expired?" do
    it "验证码过期时返回 true" do
      sms = create(:sms_verification, expires_at: 1.minute.ago)
      expect(sms.expired?).to be true
    end

    it "验证码未过期时返回 false" do
      sms = create(:sms_verification, expires_at: 5.minutes.from_now)
      expect(sms.expired?).to be false
    end
  end

  describe "#mark_verified!" do
    it "将验证码标记为已验证" do
      sms = create(:sms_verification, verified: false)
      sms.mark_verified!
      expect(sms.reload.verified).to be true
    end
  end
end
