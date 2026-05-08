# frozen_string_literal: true

require "openssl"
require "net/http"
require "json"
require "securerandom"

# 微信支付 App 支付服务（v3 API）
# 生成微信预支付订单参数（供客户端调起微信支付 SDK）
class WechatPaymentService
  class PaymentError < StandardError; end

  GATEWAY = "https://api.mch.weixin.qq.com"

  # @param order_no [String] 商户订单号
  # @param amount [BigDecimal/Float] 支付金额（元）
  # @param subject [String] 订单标题
  # @return [Hash] 微信支付预支付参数（返回给 APP 调起支付）
  def create_prepay(order_no:, amount:, subject:)
    prepay_id = request_prepay(order_no, amount, subject)

    # 生成 APP 支付参数
    timestamp = Time.current.to_i.to_s
    nonce_str = SecureRandom.hex(16)
    message = "#{ENV.fetch('WECHAT_APP_ID')}\n#{timestamp}\n#{nonce_str}\n#{prepay_id}\n"
    pay_sign = sign_message(message)

    {
      appid: ENV.fetch("WECHAT_APP_ID"),
      partnerid: ENV.fetch("WECHAT_MCH_ID"),
      prepayid: prepay_id,
      package: "Sign=WXPay",
      noncestr: nonce_str,
      timestamp: timestamp,
      sign: pay_sign
    }
  end

  # 验证微信支付异步回调签名
  # @param headers [Hash] 回调请求头
  # @param body [String] 回调请求体
  # @return [Boolean]
  def verify_callback?(headers, body)
    # 微信支付 v3 使用平台证书验证签名，这里简化实现
    # 生产环境需要使用微信支付平台证书验证
    timestamp = headers["Wechatpay-Timestamp"]
    nonce = headers["Wechatpay-Nonce"]
    signature = headers["Wechatpay-Signature"]
    serial = headers["Wechatpay-Serial"]

    return false if timestamp.blank? || nonce.blank? || signature.blank?

    message = "#{timestamp}\n#{nonce}\n#{body}\n"
    # 使用微信平台证书验证（生产环境需要从微信获取）
    platform_certificate = ENV.fetch("WECHAT_PLATFORM_CERT", nil)
    return false unless platform_certificate

    public_key = OpenSSL::PKey::RSA.new(platform_certificate)
    public_key.verify(
      OpenSSL::Digest.new("SHA256"),
      Base64.decode64(signature),
      message
    )
  end

  private

  def request_prepay(order_no, amount, subject)
    url = "#{GATEWAY}/v3/pay/transactions/app"
    body = {
      appid: ENV.fetch("WECHAT_APP_ID"),
      mchid: ENV.fetch("WECHAT_MCH_ID"),
      description: subject,
      out_trade_no: order_no,
      notify_url: ENV.fetch("WECHAT_NOTIFY_URL"),
      amount: {
        total: (amount.to_f * 100).round, # 转为分
        currency: "CNY"
      }
    }

    http = Net::HTTP.new("api.mch.weixin.qq.com", 443)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["Authorization"] = build_auth_header("POST", "/v3/pay/transactions/app", body)
    request.body = JSON.generate(body)

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)["prepay_id"]
    else
      raise PaymentError, "WeChat prepay failed: #{response.code} #{response.body.to_s.force_encoding('UTF-8')}"
    end
  end

  def build_auth_header(method, url, body)
    timestamp = Time.current.to_i.to_s
    nonce = SecureRandom.hex(16)
    body_str = JSON.generate(body) if body.is_a?(Hash)
    message = "#{method}\n#{url}\n#{timestamp}\n#{nonce}\n#{body_str || ''}\n"
    signature = sign_message(message)

    "WECHATPAY2-SHA256-RSA2048 mchid=\"#{ENV.fetch('WECHAT_MCH_ID')}\",nonce_str=\"#{nonce}\",timestamp=\"#{timestamp}\",serial_no=\"#{ENV.fetch('WECHAT_API_CERT_SERIAL')}\",signature=\"#{signature}\""
  end

  def sign_message(message)
    private_key = OpenSSL::PKey::RSA.new(ENV.fetch("WECHAT_API_CERT"))
    Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), message))
  end
end
