# frozen_string_literal: true

require "net/http"
require "json"

# 微信 OAuth 登录服务
# 通过客户端传来的 code 换取 openid
class WechatAuthService
  ACCESS_TOKEN_URL = "https://api.weixin.qq.com/sns/oauth2/access_token".freeze

  def initialize
    @app_id = ENV.fetch("WECHAT_APP_ID")
    @app_secret = ENV.fetch("WECHAT_APP_SECRET")
  end

  # 通过授权码换取 openid
  # @param code [String] 微信返回的授权码
  # @return [String] openid
  def get_openid(code)
    uri = URI(ACCESS_TOKEN_URL)
    uri.query = URI.encode_www_form({
                                      "appid" => @app_id,
                                      "secret" => @app_secret,
                                      "code" => code,
                                      "grant_type" => "authorization_code"
                                    })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    result = JSON.parse(response.body)

    if result["errcode"]
      Rails.logger.error("微信授权失败: #{result.inspect}")
      raise StandardError, result["errmsg"] || "微信授权失败"
    end

    result["openid"]
  rescue StandardError => e
    Rails.logger.error("微信请求异常: #{e.message}")
    raise e
  end
end
