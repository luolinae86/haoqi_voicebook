# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlipayPaymentService do
  describe "#create_order" do
    it "returns a payment order string" do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      allow(ENV).to receive(:fetch).with("ALIPAY_APP_ID").and_return("test_app_id")
      allow(ENV).to receive(:fetch).with("ALIPAY_PRIVATE_KEY").and_return(private_key.to_pem)
      allow(ENV).to receive(:fetch).with("ALIPAY_NOTIFY_URL").and_return("https://example.com/callback")

      service = AlipayPaymentService.new
      result = service.create_order(
        order_no: "VB20260101TEST",
        amount: 19.90,
        subject: "月度会员"
      )

      expect(result).to be_a(String)
      expect(result).to include("app_id=test_app_id")
      expect(result).to include("biz_content")
      expect(result).to include("19.90")
      expect(result).to include("sign=")
    end
  end

  describe "#verify_callback?" do
    it "returns true when signature is valid" do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      public_key = private_key.public_key

      allow(ENV).to receive(:fetch).with("ALIPAY_PUBLIC_KEY").and_return(public_key.to_pem)

      params = {
        "out_trade_no" => "VB20260101TEST",
        "trade_status" => "TRADE_SUCCESS",
        "total_amount" => "19.90"
      }

      string_to_sign = params.sort.to_h.map { |k, v| "#{k}=#{v}" }.join("&")
      signature = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), string_to_sign))
      params["sign"] = signature
      params["sign_type"] = "RSA2"

      service = AlipayPaymentService.new
      expect(service.verify_callback?(params)).to be true
    end

    it "returns false when signature is invalid" do
      public_key = OpenSSL::PKey::RSA.generate(2048)
      allow(ENV).to receive(:fetch).with("ALIPAY_PUBLIC_KEY").and_return(public_key.to_pem)

      params = {
        "out_trade_no" => "VB20260101TEST",
        "trade_status" => "TRADE_SUCCESS",
        "sign" => "invalid_signature",
        "sign_type" => "RSA2"
      }

      service = AlipayPaymentService.new
      expect(service.verify_callback?(params)).to be false
    end
  end
end
