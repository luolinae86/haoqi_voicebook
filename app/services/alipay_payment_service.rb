# frozen_string_literal: true

require "openssl"
require "net/http"
require "json"

# 支付宝 App 支付服务
# 生成支付宝 App 支付订单参数（供客户端调起支付宝 SDK）
class AlipayPaymentService
  class PaymentError < StandardError; end

  # @param order_no [String] 商户订单号
  # @param amount [BigDecimal/Float] 支付金额（元）
  # @param subject [String] 订单标题
  # @return [String] 支付宝支付订单字符串（直接返回给 APP）
  def create_order(order_no:, amount:, subject:)
    sign_params = build_sign_params(order_no, amount, subject)

    # 支付宝要求：对原始参数字符串签名，而不是编码后的
    raw_string = sign_params.sort.map { |k, v| "#{k}=#{v}" }.join("&")
    sign = rsa_sign(raw_string)

    # 所有参数值（含 sign）统一 URL 编码后拼接
    all_params = sign_params.merge(sign: sign)
    all_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
  end

  # 验证支付宝异步回调签名
  # @param params [Hash] 支付宝回调参数
  # @return [Boolean]
  def verify_callback?(params)
    # 兼容 Grape 返回的 symbol keys，统一转为 string keys
    params = params.transform_keys(&:to_s)

    sign = params.delete("sign")
    sign_type = params.delete("sign_type")

    Rails.logger.info("[AlipayCallback] sign_type=#{sign_type}, sign=#{sign&.to_s&.[](0..20)}, params_keys=#{params.keys.inspect}")

    sorted_params = params.sort.to_h
    string_to_sign = sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")

    Rails.logger.info("[AlipayCallback] string_to_sign=#{string_to_sign[0..200]}")

    if sign_type == "RSA2"
      public_key = OpenSSL::PKey::RSA.new(alipay_response_public_key)
      result = public_key.verify(
        OpenSSL::Digest.new("SHA256"),
        Base64.decode64(sign),
        string_to_sign
      )
      Rails.logger.info("[AlipayCallback] verify_result=#{result}")
      result
    else
      Rails.logger.info("[AlipayCallback] unsupported sign_type=#{sign_type}")
      false
    end
  end

  private

  def private_key
    @private_key ||= OpenSSL::PKey::RSA.new(ensure_pem_private_key(ENV.fetch("ALIPAY_PRIVATE_KEY")))
  end

  def alipay_response_public_key
    @alipay_response_public_key ||= OpenSSL::PKey::RSA.new(ensure_pem_public_key(ENV.fetch("ALIPAY_RESPONSE_PUBLIC_KEY")))
  end

  def ensure_pem_private_key(str)
    return str if str.include?("BEGIN")
    "-----BEGIN RSA PRIVATE KEY-----\n#{str}\n-----END RSA PRIVATE KEY-----"
  end

  def ensure_pem_public_key(str)
    return str if str.include?("BEGIN")
    "-----BEGIN PUBLIC KEY-----\n#{str}\n-----END PUBLIC KEY-----"
  end

  def build_sign_params(order_no, amount, subject)
    {
      app_id: ENV.fetch("ALIPAY_APP_ID"),
      biz_content: JSON.generate({
                                   timeout_express: "30m",
                                   product_code: "QUICK_MSECURITY_PAY",
                                   total_amount: format("%.2f", amount),
                                   subject: subject,
                                   body: subject,
                                   out_trade_no: order_no
                                 }),
      charset: "utf-8",
      method: "alipay.trade.app.pay",
      notify_url: ENV.fetch("ALIPAY_NOTIFY_URL"),
      timestamp: Time.current.strftime("%Y-%m-%d %H:%M:%S"),
      version: "1.0",
      sign_type: "RSA2"
    }
  end

  def rsa_sign(string_to_sign)
    Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), string_to_sign))
  end
end
