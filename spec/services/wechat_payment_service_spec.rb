# frozen_string_literal: true

require "rails_helper"

RSpec.describe WechatPaymentService do
  describe "#create_prepay" do
    it "returns payment parameters for APP" do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      allow(ENV).to receive(:fetch).with("WECHAT_APP_ID").and_return("wx_test_app_id")
      allow(ENV).to receive(:fetch).with("WECHAT_MCH_ID").and_return("1234567890")
      allow(ENV).to receive(:fetch).with("WECHAT_API_CERT").and_return(private_key.to_pem)
      allow(ENV).to receive(:fetch).with("WECHAT_API_CERT_SERIAL").and_return("test_serial")
      allow(ENV).to receive(:fetch).with("WECHAT_NOTIFY_URL").and_return("https://example.com/callback")

      stub_request(:post, "https://api.mch.weixin.qq.com/v3/pay/transactions/app")
        .to_return(
          status: 200,
          body: JSON.generate({ prepay_id: "wx20260101test_prepay" }),
          headers: { "Content-Type" => "application/json" }
        )

      service = WechatPaymentService.new
      result = service.create_prepay(
        order_no: "VB20260101TEST",
        amount: 19.90,
        subject: "月度会员"
      )

      expect(result).to be_a(Hash)
      expect(result[:appid]).to eq("wx_test_app_id")
      expect(result[:partnerid]).to eq("1234567890")
      expect(result[:prepayid]).to eq("wx20260101test_prepay")
      expect(result[:package]).to eq("Sign=WXPay")
      expect(result[:noncestr]).to be_present
      expect(result[:timestamp]).to be_present
      expect(result[:sign]).to be_present
    end

    it "raises error when prepay request fails" do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      allow(ENV).to receive(:fetch).with("WECHAT_APP_ID").and_return("wx_test_app_id")
      allow(ENV).to receive(:fetch).with("WECHAT_MCH_ID").and_return("1234567890")
      allow(ENV).to receive(:fetch).with("WECHAT_API_CERT").and_return(private_key.to_pem)
      allow(ENV).to receive(:fetch).with("WECHAT_API_CERT_SERIAL").and_return("test_serial")
      allow(ENV).to receive(:fetch).with("WECHAT_NOTIFY_URL").and_return("https://example.com/callback")

      stub_request(:post, "https://api.mch.weixin.qq.com/v3/pay/transactions/app")
        .to_return(
          status: 400,
          body: JSON.generate({ code: "INVALID_REQUEST", message: "订单号重复" })
        )

      service = WechatPaymentService.new
      expect do
        service.create_prepay(
          order_no: "VB20260101TEST",
          amount: 19.90,
          subject: "月度会员"
        )
      end.to raise_error(WechatPaymentService::PaymentError)
    end
  end

  describe "#verify_callback?" do
    it "returns true when signature is valid" do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("WECHAT_PLATFORM_CERT", nil).and_return(private_key.public_key.to_pem)

      body = JSON.generate({ out_trade_no: "VB20260101TEST", trade_state: "SUCCESS" })
      message = "1700000000\ntest-nonce\n#{body}\n"
      signature = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), message))

      headers = {
        "Wechatpay-Timestamp" => "1700000000",
        "Wechatpay-Nonce" => "test-nonce",
        "Wechatpay-Signature" => signature,
        "Wechatpay-Serial" => "test-serial"
      }

      service = WechatPaymentService.new
      expect(service.verify_callback?(headers, body)).to be true
    end

    it "returns false when platform cert is not configured" do
      allow(ENV).to receive(:fetch).with("WECHAT_PLATFORM_CERT", nil).and_return(nil)

      service = WechatPaymentService.new
      expect(service.verify_callback?({}, "{}")).to be false
    end
  end
end
