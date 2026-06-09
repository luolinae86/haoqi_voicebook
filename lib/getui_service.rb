# frozen_string_literal: true

require 'securerandom'
require 'net/http'
require 'cgi'

# 个推推送服务封装（基于个推 V2 API）
# 使用方式：
#   service = GetuiService.new
#   service.push_to_single(cid, title, body, push_type: :notification)  # 单推
#   service.push_to_batch(cid_list, title, body)                        # 批量单推
#   service.push_to_all(title, body)                                     # 群推/全推
#
# push_type 可选值：
#   :notification - 通知消息（默认），在通知栏显示，支持离线推送
#   :transmission - 透传消息，不在通知栏显示，需要 App 在线才能收到
class GetuiService
  class PushError < StandardError; end

  BASE_URL = 'https://restapi.getui.com/v2'

  def initialize
    raise PushError, '个推配置缺失，请检查 GE_TUI_* 环境变量' unless GE_TUI_APP_ID && GE_TUI_APP_KEY && GE_TUI_MASTER_SECRET
  end

  # 单推：推给指定一个 CID
  # @param cid [String] 客户端 CID
  # @param title [String] 通知标题（透传模式下可选）
  # @param body [String] 通知内容（透传模式下可选）
  # @param payload [Hash] 附加数据
  # @param push_type [Symbol] :notification（通知消息，默认）或 :transmission（透传消息）
  # @return [Hash] 个推返回结果
  def push_to_single(cid, title = nil, body = nil, payload: {}, push_type: :notification)
    raise ArgumentError, 'cid 不能为空' if cid.blank?

    request_body = {
      request_id: SecureRandom.uuid,
      audience: { cid: [cid] },
      push_message: push_type == :transmission ? build_transmission(payload) : build_notification(title, body, payload)
    }

    api_request('push/single/cid', request_body)
  end

  # 批量单推
  # @param cid_list [Array<String>] CID 列表
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 附加数据
  # @param push_type [Symbol] :notification 或 :transmission
  # @return [Hash] 个推返回结果
  def push_to_batch(cid_list, title = nil, body = nil, payload: {}, push_type: :notification)
    return {} if cid_list.blank?

    request_body = {
      request_id: SecureRandom.uuid,
      push_message: push_type == :transmission ? build_transmission(payload) : build_notification(title, body, payload),
      cid: cid_list
    }

    api_request('push/list/cid', request_body)
  end

  # 群推：推给所有在线用户
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 附加数据
  # @param push_type [Symbol] :notification 或 :transmission
  # @return [Hash] 个推返回结果
  def push_to_all(title = nil, body = nil, payload: {}, push_type: :notification)
    request_body = {
      request_id: SecureRandom.uuid,
      audience: { all: 'all' },
      push_message: push_type == :transmission ? build_transmission(payload) : build_notification(title, body, payload)
    }

    api_request('push/app', request_body)
  end

  # 查询用户在线状态
  # @param cid [String] 客户端 CID
  # @return [Hash] 个推返回结果
  def check_user_status(cid)
    uri = URI("#{BASE_URL}/#{GE_TUI_APP_ID}/user/#{cid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.path)
    request['token'] = auth_token

    response = http.request(request)
    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("[GetuiService] user_status failed: #{e.class}: #{e.message}")
    raise PushError, "查询用户状态失败: #{e.message}"
  end

  private

  # 构建通知消息（在通知栏显示，支持离线推送）
  def build_notification(title, body, payload)
    notification = {
      title: title,
      body: body,
      click_type: 'intent'
    }
    notification[:intent] = build_payload_intent(payload) if payload.any?
    { notification: notification }
  end

  # 构建透传消息（不在通知栏显示，需 App 在线）
  # V2 API 不支持纯透传，用极简短标题 + intent 方式传递 payload
  def build_transmission(payload)
    {
      notification: {
        title: '.',
        body: '.',
        click_type: 'intent',
        intent: build_payload_intent(payload)
      }
    }
  end

  # 构建 payload intent URI
  # 格式：intent://push?payload=JSON#Intent;scheme=zheliapp;package=com.zheli.zheliapp;component=com.zheli.zheliapp/.MainActivity;action=android.intent.action.VIEW;end
  def build_payload_intent(payload)
    payload_json = payload.to_json
    encoded_payload = CGI.escape(payload_json)
    "intent://push?payload=#{encoded_payload}#Intent;scheme=zheliapp;package=com.zheli.zheliapp;component=com.zheli.zheliapp/.MainActivity;action=android.intent.action.VIEW;end"
  end

  # 发送 API 请求
  def api_request(endpoint, body)
    uri = URI("#{BASE_URL}/#{GE_TUI_APP_ID}/#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['token'] = auth_token
    request.body = body.to_json

    response = http.request(request)
    result = JSON.parse(response.body)

    if result['code'] != 0
      Rails.logger.error("[GetuiService] #{endpoint} failed: #{result}")
      raise PushError, "推送失败: #{result['msg']}"
    end

    result
  rescue StandardError => e
    Rails.logger.error("[GetuiService] #{endpoint} error: #{e.class}: #{e.message}")
    raise PushError, "推送异常: #{e.message}"
  end

  # 获取认证 token（带缓存）
  def auth_token
    cached = @auth_token_cache
    return cached[:token] if cached && cached[:expires_at] > Time.now.to_i * 1000

    timestamp = (Time.now.to_f * 1000).to_i
    sign = Digest::SHA256.hexdigest("#{GE_TUI_APP_KEY}#{timestamp}#{GE_TUI_MASTER_SECRET}")
    auth_body = {
      sign: sign,
      appkey: GE_TUI_APP_KEY,
      timestamp: timestamp.to_s
    }.to_json

    uri = URI("#{BASE_URL}/#{GE_TUI_APP_ID}/auth")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = auth_body

    response = http.request(request)
    result = JSON.parse(response.body)

    raise PushError, "获取 auth_token 失败: #{result}" unless result['code'] == 0

    @auth_token_cache = {
      token: result.dig('data', 'token'),
      expires_at: result.dig('data', 'expire_time').to_i
    }
    @auth_token_cache[:token]
  end
end
