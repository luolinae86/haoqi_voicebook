# frozen_string_literal: true

require 'securerandom'
require 'net/http'

# 个推推送服务封装（基于个推 V2 API）
# 使用方式：
#   service = GetuiService.new
#   service.push_to_single(cid, title, body)          # 单推（Android 通知栏）
#   service.push_to_batch(cid_list, title, body)      # 批量单推
#   service.push_to_all(title, body)                   # 群推/全推
class GetuiService
  class PushError < StandardError; end

  BASE_URL = 'https://restapi.getui.com/v2'

  def initialize
    raise PushError, '个推配置缺失，请检查 GE_TUI_* 环境变量' unless GE_TUI_APP_ID && GE_TUI_APP_KEY && GE_TUI_MASTER_SECRET
  end

  # 单推：推给指定一个 CID（Android 通知栏）
  # @param cid [String] 客户端 CID
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 附加数据（可选）
  # @return [Hash] 个推返回结果
  def push_to_single(cid, title, body, payload: {})
    raise ArgumentError, 'cid 不能为空' if cid.blank?

    request_body = {
      request_id: SecureRandom.uuid,
      audience: { cid: [cid] },
      push_message: {
        notification: {
          title: title,
          body: body,
          click_type: 'startapp',
          payload: payload.to_json
        }
      }
    }

    api_request('push/single/cid', request_body)
  end

  # 批量单推：先创建任务再推送
  # @param cid_list [Array<String>] CID 列表
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 附加数据
  # @return [Hash] 个推返回结果
  def push_to_batch(cid_list, title, body, payload: {})
    return {} if cid_list.blank?

    # 先创建任务
    task_body = {
      request_id: SecureRandom.uuid,
      push_message: {
        notification: {
          title: title,
          body: body,
          click_type: 'startapp',
          payload: payload.to_json
        }
      },
      cid: cid_list
    }

    api_request('push/list/cid', task_body)
  end

  # 群推：推给所有在线用户
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 附加数据
  # @return [Hash] 个推返回结果
  def push_to_all(title, body, payload: {})
    request_body = {
      request_id: SecureRandom.uuid,
      audience: { all: 'all' },
      push_message: {
        notification: {
          title: title,
          body: body,
          click_type: 'startapp',
          payload: payload.to_json
        }
      }
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
