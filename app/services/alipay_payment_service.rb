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
    encoded_params = encode_params(sign_params)

    # 对 sign_params 进行签名
    sign = rsa_sign(encoded_params)

    # 完整的支付参数串
    "#{encoded_params}&sign=#{CGI.escape(sign)}"
  end

  # 验证支付宝异步回调签名
  # @param params [Hash] 支付宝回调参数
  # @return [Boolean]
  def verify_callback?(params)
    sign = params.delete("sign")
    sign_type = params.delete("sign_type")

    sorted_params = params.sort.to_h
    string_to_sign = sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")

    if sign_type == "RSA2"
      public_key = OpenSSL::PKey::RSA.new(ENV.fetch("ALIPAY_PUBLIC_KEY"))
      public_key.verify(
        OpenSSL::Digest.new("SHA256"),
        Base64.decode64(sign),
        string_to_sign
      )
    else
      false
    end
  end

  private

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

  def encode_params(params)
    params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
  end

  def rsa_sign(encoded_string)
    private_key = OpenSSL::PKey::RSA.new(ENV.fetch("ALIPAY_PRIVATE_KEY"))
    Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), encoded_string))
  end
end
