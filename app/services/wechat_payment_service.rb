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
    # 微信支付 v3 使用平台证书验证签名
    timestamp = headers["Wechatpay-Timestamp"]
    nonce = headers["Wechatpay-Nonce"]
    signature = headers["Wechatpay-Signature"]
    serial = headers["Wechatpay-Serial"]

    return false if timestamp.blank? || nonce.blank? || signature.blank?

    message = "#{timestamp}\n#{nonce}\n#{body}\n"

    # 使用微信平台公钥证书验证
    # 注意：生产环境需要从微信获取平台证书，这里简化处理
    platform_cert_pem = ENV.fetch("WECHAT_PLATFORM_CERT", nil)

    if platform_cert_pem.present?
      public_key = OpenSSL::PKey::RSA.new(platform_cert_pem)
      return public_key.verify(
        OpenSSL::Digest.new("SHA256"),
        Base64.decode64(signature),
        message
      )
    end

    # 如果没有平台证书，记录日志并返回 false
    Rails.logger.warn("[WechatPayment] Platform certificate not configured, serial: #{serial}")
    false
  rescue StandardError => e
    Rails.logger.error("[WechatPayment] verify_callback error: #{e.message}")
    false
  end

  # 解密微信支付回调通知
  # @param ciphertext [String] 加密数据
  # @param associated_data [String] 附加数据
  # @param nonce [String] 随机串
  # @return [Hash] 解密后的数据
  def decrypt_callback(ciphertext:, associated_data:, nonce:)
    v3_key = ENV.fetch("WECHAT_API_V3_KEY")

    cipher = OpenSSL::Cipher.new("aes-256-gcm")
    cipher.decrypt
    cipher.key = v3_key
    cipher.iv = nonce
    cipher.auth_data = associated_data

    decoded_ciphertext = Base64.decode64(ciphertext)
    # GCM 模式的 tag 在最后 16 字节
    cipher.auth_tag = decoded_ciphertext[-16, 16]
    plaintext = cipher.update(decoded_ciphertext[0..-17]) + cipher.final

    JSON.parse(plaintext)
  rescue StandardError => e
    Rails.logger.error("[WechatPayment] decrypt_callback error: #{e.message}")
    nil
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

    raise PaymentError, "WeChat prepay failed: #{response.code} #{response.body.to_s.force_encoding('UTF-8')}" unless response.code == "200"

    JSON.parse(response.body)["prepay_id"]
  end

  def build_auth_header(method, url, body)
    timestamp = Time.current.to_i.to_s
    nonce = SecureRandom.hex(16)
    body_str = body.is_a?(Hash) ? JSON.generate(body) : (body || "")
    message = "#{method}\n#{url}\n#{timestamp}\n#{nonce}\n#{body_str}\n"
    signature = sign_message(message)

    "WECHATPAY2-SHA256-RSA2048 mchid=\"#{ENV.fetch('WECHAT_MCH_ID')}\",nonce_str=\"#{nonce}\",timestamp=\"#{timestamp}\",serial_no=\"#{ENV.fetch('WECHAT_API_CERT_SERIAL')}\",signature=\"#{signature}\""
  end

  def sign_message(message)
    # 使用商户私钥签名
    private_key_pem = ENV.fetch("WECHAT_API_KEY")
    private_key = OpenSSL::PKey::RSA.new(private_key_pem)
    Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), message))
  end
end
