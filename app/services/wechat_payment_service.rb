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

  # 类级别缓存平台证书，避免每次请求都下载
  @@platform_certs_cache = {}
  @@certs_cache_time = nil
  CERTS_CACHE_TTL = 3600 # 证书缓存1小时

  # @param order_no [String] 商户订单号
  # @param amount [BigDecimal/Float] 支付金额（元）
  # @param subject [String] 订单标题
  # @return [Hash] 微信支付预支付参数（返回给 APP 调起支付）
  def create_prepay(order_no:, amount:, subject:)
    prepay_id = request_prepay(order_no, amount, subject, trade_type: 'app')

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

  # Native 支付（扫码支付，适用于平板等设备）
  # @param order_no [String] 商户订单号
  # @param amount [BigDecimal/Float] 支付金额（元）
  # @param subject [String] 订单标题
  # @return [Hash] { code_url: "weixin://wxpay/..." }
  def create_native_prepay(order_no:, amount:, subject:)
    code_url = request_prepay(order_no, amount, subject, trade_type: 'native')

    {
      code_url: code_url,
      order_no: order_no
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

    # 获取微信平台证书（优先从环境变量，否则自动下载）
    public_key = get_platform_public_key(serial)

    if public_key
      return public_key.verify(
        OpenSSL::Digest.new("SHA256"),
        Base64.decode64(signature),
        message
      )
    end

    Rails.logger.warn("[WechatPayment] Cannot find platform certificate for serial: #{serial}")
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

  def request_prepay(order_no, amount, subject, trade_type: 'app')
    url = "#{GATEWAY}/v3/pay/transactions/#{trade_type}"
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
    request["Authorization"] = build_auth_header("POST", "/v3/pay/transactions/#{trade_type}", body)
    request.body = JSON.generate(body)

    response = http.request(request)

    raise PaymentError, "WeChat prepay failed: #{response.code} #{response.body.to_s.force_encoding('UTF-8')}" unless response.code == "200"

    result = JSON.parse(response.body)
    trade_type == 'native' ? result["code_url"] : result["prepay_id"]
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
    # 使用商户私钥签名（优先从文件读取，其次从环境变量）
    private_key_pem = if File.exist?('/rails/config/certs/apiclient_key.pem')
                        File.read('/rails/config/certs/apiclient_key.pem')
                      else
                        ENV.fetch("WECHAT_API_KEY") do
                          require 'base64'
                          Base64.decode64(ENV.fetch("WECHAT_API_KEY_B64"))
                        end
                      end
    private_key = OpenSSL::PKey::RSA.new(private_key_pem)
    Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), message))
  end

  # 获取微信平台公钥（用于验证回调签名）
  # @param serial [String] 证书序列号（公钥模式下为 PUB_KEY_ID_xxx）
  # @return [OpenSSL::PKey::RSA, nil]
  def get_platform_public_key(serial)
    # 从环境变量获取公钥
    env_cert = ENV.fetch("WECHAT_PLATFORM_CERT", nil)
    if env_cert.present?
      # kamal 环境变量换行被转义为字面量 \n 或 \\n，统一还原为真实换行
      env_cert = env_cert.gsub(/\\+n/, "\n")

      # 如果配置了公钥 ID，验证 serial 是否匹配
      pub_key_id = ENV.fetch("WECHAT_PLATFORM_CERT_PUB_KEY_ID", nil)
      if pub_key_id.present?
        if serial == pub_key_id
          return OpenSSL::PKey::RSA.new(env_cert)
        else
          Rails.logger.warn("[WechatPayment] Public key serial mismatch: expected #{pub_key_id}, got #{serial}")
          return nil
        end
      end
      # 未配置公钥 ID 时，直接返回（向后兼容）
      return OpenSSL::PKey::RSA.new(env_cert)
    end

    # 公钥模式下 /v3/certificates 接口不可用，跳过自动下载
    Rails.logger.warn("[WechatPayment] WECHAT_PLATFORM_CERT not configured, serial: #{serial}")
    nil
  end

  # 刷新平台证书缓存（如需要）
  def refresh_platform_certs_if_needed
    return if @@certs_cache_time && (Time.current - @@certs_cache_time) < CERTS_CACHE_TTL

    certs = download_platform_certs
    @@platform_certs_cache = certs
    @@certs_cache_time = Time.current
    Rails.logger.info("[WechatPayment] Downloaded #{certs.size} platform certificate(s)")
  rescue StandardError => e
    Rails.logger.error("[WechatPayment] Failed to download platform certs: #{e.message}")
  end

  # 从微信下载平台证书
  # @return [Hash] { serial_no => OpenSSL::PKey::RSA }
  def download_platform_certs
    url = "#{GATEWAY}/v3/certificates"

    http = Net::HTTP.new("api.mch.weixin.qq.com", 443)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["Accept"] = "application/json"
    request["Authorization"] = build_auth_header("GET", "/v3/certificates", nil)

    response = http.request(request)

    unless response.code == "200"
      raise PaymentError, "Failed to download certs: #{response.code} #{response.body.to_s.force_encoding('UTF-8')}"
    end

    data = JSON.parse(response.body)["data"] || []
    certs = {}

    data.each do |cert_info|
      serial = cert_info["serial_no"]
      encrypted_cert = cert_info["encrypt_certificate"]

      # 解密证书内容
      cert_pem = decrypt_certificate(
        ciphertext: encrypted_cert["ciphertext"],
        nonce: encrypted_cert["nonce"],
        associated_data: encrypted_cert["associated_data"]
      )

      certs[serial] = OpenSSL::PKey::RSA.new(cert_pem) if cert_pem
    end

    certs
  end

  # 解密微信返回的加密证书
  # @return [String, nil] PEM 格式的证书
  def decrypt_certificate(ciphertext:, nonce:, associated_data:)
    v3_key = ENV.fetch("WECHAT_API_V3_KEY")

    cipher = OpenSSL::Cipher.new("aes-256-gcm")
    cipher.decrypt
    cipher.key = v3_key
    cipher.iv = nonce
    cipher.auth_data = associated_data || ""

    decoded = Base64.decode64(ciphertext)
    # GCM 模式 tag 在最后 16 字节
    cipher.auth_tag = decoded[-16, 16]
    plaintext = cipher.update(decoded[0..-17]) + cipher.final

    plaintext
  rescue StandardError => e
    Rails.logger.error("[WechatPayment] decrypt_certificate error: #{e.message}")
    nil
  end
end
