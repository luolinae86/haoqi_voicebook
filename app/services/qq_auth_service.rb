# frozen_string_literal: true

require "net/http"
require "json"

# QQ OAuth 登录服务
# 通过客户端传来的 code 换取 openid
class QqAuthService
  ACCESS_TOKEN_URL = "https://graph.qq.com/oauth2.0/token".freeze
  OPENID_URL = "https://graph.qq.com/oauth2.0/me".freeze

  def initialize
    @app_id = ENV.fetch("QQ_APP_ID")
    @app_key = ENV.fetch("QQ_APP_KEY")
  end

  # 通过授权码换取 access_token
  # @param code [String] QQ返回的授权码
  # @return [String] access_token
  def get_access_token(code)
    uri = URI(ACCESS_TOKEN_URL)
    uri.query = URI.encode_www_form({
                                      "grant_type" => "authorization_code",
                                      "client_id" => @app_id,
                                      "client_secret" => @app_key,
                                      "code" => code,
                                      "redirect_uri" => ""
                                    })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    parse_form_response(response.body)
  end

  # 通过 access_token 获取 openid
  # @param access_token [String] QQ access_token
  # @return [String] openid
  def get_openid(access_token)
    uri = URI(OPENID_URL)
    uri.query = URI.encode_www_form({
                                      "access_token" => access_token
                                    })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    body = response.body

    # QQ 返回的格式为: callback( {"client_id":"xxx","openid":"xxx"} );
    json_str = body.match(/\((.*)\)/)
    raise StandardError, "QQ openid 解析失败" unless json_str

    result = JSON.parse(json_str[1])
    raise StandardError, result["error_description"] if result["error"]
    raise StandardError, result["msg"] if result["code"] && result["code"] != 0

    result["openid"]
  rescue StandardError => e
    Rails.logger.error("QQ请求异常: #{e.message}")
    raise e
  end

  # 通过授权码换取 openid（完整流程）
  # @param code [String] QQ返回的授权码
  # @return [String] openid
  def get_openid_by_code(code)
    access_token = get_access_token(code)
    get_openid(access_token)
  end

  private

  # QQ 返回的是表单格式: access_token=xxx&expires_in=xxx&refresh_token=xxx
  # 或错误格式: error=xxx&error_description=xxx
  def parse_form_response(body)
    params = URI.decode_www_form(body).to_h
    raise StandardError, params["error_description"] || "QQ 授权失败" if params["error"]

    params["access_token"]
  end
end
