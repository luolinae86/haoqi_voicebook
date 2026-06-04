# frozen_string_literal: true

require 'net/http'
require 'json'

# 微信 OAuth 登录服务
class WechatAuthService
  ACCESS_TOKEN_URL = 'https://api.weixin.qq.com/sns/oauth2/access_token'.freeze
  USERINFO_URL = 'https://api.weixin.qq.com/sns/userinfo'.freeze

  def initialize
    @app_id = ENV.fetch('WECHAT_APP_ID')
    @app_secret = ENV.fetch('WECHAT_APP_SECRET')
  end

  # 通过授权码换取 access_token 和 openid
  # @param code [String] 微信返回的授权码
  # @return [Hash] { access_token:, openid: }
  def get_credentials(code)
    uri = URI(ACCESS_TOKEN_URL)
    uri.query = URI.encode_www_form({
                                      'appid' => @app_id,
                                      'secret' => @app_secret,
                                      'code' => code,
                                      'grant_type' => 'authorization_code'
                                    })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    result = JSON.parse(response.body)

    if result['errcode']
      Rails.logger.error("微信授权失败: #{result.inspect}")
      raise StandardError, result['errmsg'] || '微信授权失败'
    end

    { access_token: result['access_token'], openid: result['openid'] }
  rescue StandardError => e
    Rails.logger.error("微信请求异常: #{e.message}")
    raise e
  end

  # 兼容旧接口：只返回 openid
  def get_openid(code)
    get_credentials(code)[:openid]
  end

  # 通过 access_token 和 openid 获取微信用户信息
  # @param access_token [String] 网页授权 token
  # @param openid [String] 用户 openid
  # @return [Hash] { nickname:, headimgurl:, sex: }
  def get_userinfo(access_token, openid)
    uri = URI(USERINFO_URL)
    uri.query = URI.encode_www_form({
                                      'access_token' => access_token,
                                      'openid' => openid,
                                      'lang' => 'zh_CN'
                                    })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    result = JSON.parse(response.body)

    if result['errcode']
      Rails.logger.error("微信获取用户信息失败: #{result.inspect}")
      raise StandardError, result['errmsg'] || '获取用户信息失败'
    end

    {
      nickname: result['nickname'],
      headimgurl: result['headimgurl'],
      sex: result['sex']
    }
  rescue StandardError => e
    Rails.logger.error("微信获取用户信息异常: #{e.message}")
    raise e
  end
end
