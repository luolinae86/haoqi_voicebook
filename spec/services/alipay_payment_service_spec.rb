# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlipayPaymentService do
  describe '#create_order' do
    it 'returns a payment order string' do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      allow(ENV).to receive(:fetch).with('ALIPAY_APP_ID').and_return('test_app_id')
      allow(ENV).to receive(:fetch).with('ALIPAY_PRIVATE_KEY').and_return(private_key.to_pem)
      allow(ENV).to receive(:fetch).with('ALIPAY_NOTIFY_URL').and_return('https://example.com/callback')

      service = AlipayPaymentService.new
      result = service.create_order(
        order_no: 'VB20260101TEST',
        amount: 19.90,
        subject: '月度会员'
      )

      expect(result).to be_a(String)
      expect(result).to include('app_id=test_app_id')
      expect(result).to include('biz_content')
      expect(result).to include('19.90')
      expect(result).to include('sign=')
    end
  end

  describe '#verify_callback_with_raw_body?' do
    it 'returns true when signature is valid with URL-encoded raw body' do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      public_key = private_key.public_key

      allow(ENV).to receive(:fetch).with('ALIPAY_RESPONSE_PUBLIC_KEY').and_return(public_key.to_pem)

      # Simulate Alipay callback params (with values that need URL-encoding)
      params = {
        'app_id' => '2021006157653225',
        'notify_time' => '2026-06-02 14:48:27',
        'out_trade_no' => 'VB20260101TEST',
        'sign_type' => 'RSA2',
        'trade_status' => 'TRADE_SUCCESS',
        'total_amount' => '19.90'
      }

      # Alipay signs without sign_type in the string_to_sign
      string_to_sign = params.except('sign_type').sort.map { |k, v| "#{k}=#{v}" }.join('&')
      signature = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new('SHA256'), string_to_sign))

      # Build URL-encoded raw body (simulating what Alipay POSTs)
      raw_body = params.merge('sign' => signature).sort.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')

      service = AlipayPaymentService.new
      expect(service.verify_callback_with_raw_body?(params, raw_body)).to be true
    end

    it 'returns false when signature is invalid' do
      public_key = OpenSSL::PKey::RSA.generate(2048)
      allow(ENV).to receive(:fetch).with('ALIPAY_RESPONSE_PUBLIC_KEY').and_return(public_key.to_pem)

      raw_body = 'app_id=123&out_trade_no=VB123&sign=invalid&sign_type=RSA2&trade_status=TRADE_SUCCESS'

      service = AlipayPaymentService.new
      expect(service.verify_callback_with_raw_body?({}, raw_body)).to be false
    end
  end
end
