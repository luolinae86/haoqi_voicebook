# frozen_string_literal: true

require "openssl"
require "base64"
require "securerandom"
require "uri"

# 阿里云短信服务
# 使用 HTTP 签名方式调用阿里云 OpenAPI（POP 网关）
class AliyunSmsService
  ENDPOINT = "https://dysmsapi.aliyuncs.com"
  API_VERSION = "2017-05-25"

  def initialize
    @access_key_id = ENV.fetch("ALIYUN_ACCESS_KEY_ID")
    @access_key_secret = ENV.fetch("ALIYUN_ACCESS_KEY_SECRET")
  end

  # 发送验证码
  # @param phone [String] 手机号
  # @param code [String] 验证码
  # @param sign_name [String] 短信签名，默认"浙江少年儿童出版社"
  # @param template_code [String] 短信模板 CODE，默认 SMS_333840584
  # @return [Boolean] 是否发送成功
  def send_verification_code(phone, code, sign_name: "浙江少年儿童出版社", template_code: "SMS_333840584")
    send_sms(
      phone_numbers: phone,
      sign_name: sign_name,
      template_code: template_code,
      template_param: { code: code }.to_json
    )
  end

  private

  def send_sms(phone_numbers:, sign_name:, template_code:, template_param:)
    params = {
      "AccessKeyId" => @access_key_id,
      "Action" => "SendSms",
      "Format" => "JSON",
      "PhoneNumbers" => phone_numbers,
      "SignName" => sign_name,
      "TemplateCode" => template_code,
      "TemplateParam" => template_param,
      "SignatureMethod" => "HMAC-SHA1",
      "SignatureNonce" => SecureRandom.uuid,
      "SignatureVersion" => "1.0",
      "Timestamp" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
      "Version" => API_VERSION
    }

    signature = compute_signature("POST", params)
    params["Signature"] = signature

    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(params)

    response = http.request(request)
    result = JSON.parse(response.body)

    if result["Code"] == "OK"
      true
    else
      Rails.logger.error("阿里云短信发送失败: #{result.inspect}")
      false
    end
  rescue => e
    Rails.logger.error("阿里云短信请求异常: #{e.message}")
    false
  end

  def compute_signature(http_method, params)
    # 1. 构建规范化请求字符串
    canonicalized_query = params
      .map { |k, v| [encode(k), encode(v.to_s)] }
      .sort
      .map { |k, v| "#{k}=#{v}" }
      .join("&")

    # 2. 构建待签名字符串
    string_to_sign = "#{http_method}&#{encode('/')}&#{encode(canonicalized_query)}"

    # 3. 计算签名
    key = "#{@access_key_secret}&"
    digest = OpenSSL::HMAC.digest("sha1", key, string_to_sign)
    Base64.strict_encode64(digest)
  end

  def encode(value)
    URI.encode_www_form_component(value)
      .gsub("+", "%20")
      .gsub("*", "%2A")
      .gsub("%7E", "~")
  end
end
