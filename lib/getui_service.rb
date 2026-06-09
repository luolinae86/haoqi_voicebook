# frozen_string_literal: true

require 'securerandom'
require 'net/http'

# 个推推送服务封装（基于 getui gem v1 API）
# 使用方式：
#   service = GetuiService.new
#   service.push_to_single(cid, title, body)          # 单推（Android 通知栏）
#   service.push_to_batch(cid_list, title, body)      # 批量单推
#   service.push_to_all(title, body)                   # 群推/全推
class GetuiService
  class PushError < StandardError; end

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

    response = api_request('push_single', {
                             cid: cid,
                             requestid: SecureRandom.uuid[0..29],
                             message: {
                               appkey: GE_TUI_APP_KEY,
                               is_offline: true,
                               offline_expire_time: 86_400_000,
                               msgtype: 'notification'
                             },
                             notification: {
                               type: 'NOTIFICATION_MESSAGE_TYPE',
                               title: title,
                               content: body,
                               payload: payload.to_json
                             }
                           })
    raise PushError, "单推失败: #{response}" unless response['result'] == 'ok'

    response
  end

  # 批量单推：先保存消息体获取 taskid，再按列表推送
  # @param cid_list [Array<String>] CID 列表
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 附加数据
  # @return [Hash] 个推返回结果
  def push_to_batch(cid_list, title, body, payload: {})
    return {} if cid_list.blank?

    response = api_request('save_list_body', {
                             message: {
                               appkey: GE_TUI_APP_KEY,
                               is_offline: true,
                               offline_expire_time: 86_400_000,
                               msgtype: 'notification'
                             },
                             notification: {
                               type: 'NOTIFICATION_MESSAGE_TYPE',
                               title: title,
                               content: body,
                               payload: payload.to_json
                             }
                           })
    raise PushError, "批量推送失败: #{response}" unless response['result'] == 'ok'

    taskid = response['taskid']
    api_request('push_list', { cid: cid_list, taskid: taskid, need_detail: true })
  end

  # 群推：推给所有在线用户
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 附加数据
  # @return [Hash] 个推返回结果
  def push_to_all(title, body, payload: {})
    response = api_request('push_app', {
                             requestid: SecureRandom.uuid[0..29],
                             message: {
                               appkey: GE_TUI_APP_KEY,
                               is_offline: true,
                               offline_expire_time: 86_400_000,
                               msgtype: 'notification'
                             },
                             notification: {
                               type: 'NOTIFICATION_MESSAGE_TYPE',
                               title: title,
                               content: body,
                               payload: payload.to_json
                             }
                           })
    raise PushError, "群推失败: #{response}" unless response['result'] == 'ok'

    response
  end

  # 查询用户在线状态
  # @param cid [String] 客户端 CID
  # @return [Hash] 个推返回结果
  def check_user_status(cid)
    uri = URI("https://restapi.getui.com/v1/#{GE_TUI_APP_ID}/user_status/#{cid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.path)
    request['authtoken'] = auth_token

    response = http.request(request)
    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("[GetuiService] user_status failed: #{e.class}: #{e.message}")
    raise PushError, "查询用户状态失败: #{e.message}"
  end

  private

  # 发送 API 请求
  def api_request(endpoint, body)
    uri = URI("https://restapi.getui.com/v1/#{GE_TUI_APP_ID}/#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['authtoken'] = auth_token
    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  # 获取认证 token（带缓存）
  def auth_token
    cached = @auth_token_cache
    return cached[:token] if cached && cached[:expires_at] > Time.now.to_i * 1000

    sign = Digest::SHA256.hexdigest("#{GE_TUI_APP_KEY}#{Time.now.to_i * 1000}#{GE_TUI_MASTER_SECRET}")
    auth_body = {
      sign: sign,
      appkey: GE_TUI_APP_KEY,
      timestamp: Time.now.to_i * 1000
    }.to_json

    uri = URI("https://restapi.getui.com/v1/#{GE_TUI_APP_ID}/auth_sign")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request.body = auth_body

    response = http.request(request)
    result = JSON.parse(response.body)

    raise PushError, "获取 auth_token 失败: #{result}" unless result['result'] == 'ok'

    @auth_token_cache = {
      token: result['auth_token'],
      expires_at: result['expire_time'].to_i
    }
    @auth_token_cache[:token]
  end
end
