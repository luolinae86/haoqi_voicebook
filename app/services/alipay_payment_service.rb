# frozen_string_literal: true

require 'openssl'
require 'net/http'
require 'json'
require 'cgi'
require 'base64'

# 支付宝支付服务（支持 App 支付和当面付扫码支付）
class AlipayPaymentService
  class PaymentError < StandardError; end

  # App 支付：生成支付宝 App 支付订单参数（供客户端调起支付宝 SDK）
  # @param order_no [String] 商户订单号
  # @param amount [BigDecimal/Float] 支付金额（元）
  # @param subject [String] 订单标题
  # @return [String] 支付宝支付订单字符串（直接返回给 APP）
  def create_order(order_no:, amount:, subject:)
    sign_params = build_sign_params('alipay.trade.app.pay', order_no, amount, subject)

    raw_string = sign_params.sort.map { |k, v| "#{k}=#{v}" }.join('&')
    sign = rsa_sign(raw_string)

    all_params = sign_params.merge(sign: sign)
    all_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
  end

  # 当面付扫码支付：生成支付宝二维码链接
  # @param order_no [String] 商户订单号
  # @param amount [BigDecimal/Float] 支付金额（元）
  # @param subject [String] 订单标题
  # @return [Hash] { qr_code: "https://qr.alipay.com/..." }
  def create_native_order(order_no:, amount:, subject:)
    sign_params = build_sign_params('alipay.trade.precreate', order_no, amount, subject)

    raw_string = sign_params.sort.map { |k, v| "#{k}=#{v}" }.join('&')
    sign = rsa_sign(raw_string)

    all_params = sign_params.merge(sign: sign)
    form_data = {}
    all_params.each { |k, v| form_data[k.to_s] = v.to_s.encode('UTF-8') }

    response = post_to_alipay(form_data)

    qr_code = response.dig('alipay_trade_precreate_response', 'qr_code')
    raise PaymentError, "支付宝扫码支付创建失败: #{response.to_json[0..200]}" unless qr_code

    { qr_code: qr_code, order_no: order_no }
  end

  # 验证支付宝异步回调签名（使用原始 URL-encoded body）
  def verify_callback_with_raw_body?(_params, raw_body)
    pairs = raw_body.split('&').map { |p| p.split('=', 2) }

    sign_pair = pairs.find { |k, _| k == 'sign' }
    return false if sign_pair.nil?

    sign = CGI.unescape(sign_pair.last)

    string_to_sign = pairs.to_h.tap do |h|
      h.delete('sign')
      h.delete('sign_type')
    end.sort.map { |k, v| "#{k}=#{CGI.unescape(v)}" }.join('&')

    Rails.logger.info("[AlipayDebug] raw_body=#{raw_body}")
    Rails.logger.info("[AlipayDebug] string_to_sign=#{string_to_sign}")

    public_key = OpenSSL::PKey::RSA.new(alipay_response_public_key)
    result = public_key.verify(
      OpenSSL::Digest.new('SHA256'),
      Base64.decode64(sign),
      string_to_sign
    )
    Rails.logger.info("[AlipayDebug] verify_result=#{result}")
    result
  end

  # 验证支付宝异步回调签名（旧方法，保留兼容）
  def verify_callback?(params)
    params = params.transform_keys(&:to_s)

    sign = params.delete('sign')
    sign_type = params.delete('sign_type')

    Rails.logger.info("[AlipayCallback] sign_type=#{sign_type}, sign=#{sign&.to_s&.[](0..20)}, params_keys=#{params.keys.inspect}")

    sorted_params = params.sort.to_h
    string_to_sign = sorted_params.map { |k, v| "#{k}=#{v}" }.join('&')

    Rails.logger.info("[AlipayCallback] string_to_sign=#{string_to_sign[0..200]}")

    if sign_type == 'RSA2'
      public_key = OpenSSL::PKey::RSA.new(alipay_response_public_key)
      result = public_key.verify(
        OpenSSL::Digest.new('SHA256'),
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

  def post_to_alipay(params)
    uri = URI('https://openapi.alipay.com/gateway.do')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data(params)

    response = http.request(request)
    body = response.body.force_encoding('UTF-8')
    body = body.encode('UTF-8', invalid: :replace, undef: :replace) unless body.valid_encoding?
    JSON.parse(body)
  rescue JSON::ParserError => e
    raise PaymentError, "支付宝响应解析失败：#{e.message}"
  rescue StandardError => e
    raise PaymentError, "支付宝请求失败：#{e.message}"
  end

  def private_key
    @private_key ||= OpenSSL::PKey::RSA.new(ensure_pem_private_key(ENV.fetch('ALIPAY_PRIVATE_KEY')))
  end

  def alipay_response_public_key
    @alipay_response_public_key ||= OpenSSL::PKey::RSA.new(ensure_pem_public_key(ENV.fetch('ALIPAY_RESPONSE_PUBLIC_KEY')))
  end

  def ensure_pem_private_key(str)
    return str if str.include?('BEGIN')
    "-----BEGIN RSA PRIVATE KEY-----\n#{str}\n-----END RSA PRIVATE KEY-----"
  end

  def ensure_pem_public_key(str)
    return str if str.include?('BEGIN')
    "-----BEGIN PUBLIC KEY-----\n#{str}\n-----END PUBLIC KEY-----"
  end

  def build_sign_params(method, order_no, amount, subject)
    {
      charset: 'utf-8',
      app_id: ENV.fetch('ALIPAY_APP_ID'),
      method: method,
      version: '1.0',
      sign_type: 'RSA2',
      timestamp: Time.current.strftime('%Y-%m-%d %H:%M:%S'),
      notify_url: ENV.fetch('ALIPAY_NOTIFY_URL'),
      biz_content: JSON.generate({
                                   timeout_express: '30m',
                                   product_code: method == 'alipay.trade.precreate' ? 'FACE_TO_FACE_PAYMENT' : 'QUICK_MSECURITY_PAY',
                                   total_amount: format('%.2f', amount),
                                   subject: subject,
                                   body: subject,
                                   out_trade_no: order_no
                                 })
    }
  end

  def rsa_sign(string_to_sign)
    Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new('SHA256'), string_to_sign))
  end
end
