# frozen_string_literal: true

require 'securerandom'

# 个推推送服务封装（基于 getui gem v1 API）
# 使用方式：
#   service = GetuiService.new
#   service.push_to_single(cid, title, body)          # 单推
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
  # @param payload [Hash] 透传数据（可选）
  # @return [Hash] 个推返回结果
  def push_to_single(cid, title, body, payload: {})
    raise ArgumentError, 'cid 不能为空' if cid.blank?

    message = build_notification_message(title, body, payload)
    Getui.push_single(cid, message)
  rescue Getui::PushError, Getui::GenerateAuthTokenError => e
    Rails.logger.error("[GetuiService] push_to_single failed: #{e.class}: #{e.message}")
    raise PushError, "单推失败: #{e.message}"
  end

  # 批量单推：先保存消息体获取 taskid，再按列表推送
  # @param cid_list [Array<String>] CID 列表
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 透传数据
  # @return [Hash] 个推返回结果
  def push_to_batch(cid_list, title, body, payload: {})
    return {} if cid_list.blank?

    message = build_notification_message(title, body, payload)
    taskid = Getui.save_list_body(message)
    Getui.push_list(cid_list, taskid)
  rescue Getui::PushError, Getui::GenerateAuthTokenError => e
    Rails.logger.error("[GetuiService] push_to_batch failed: #{e.class}: #{e.message}")
    raise PushError, "批量推送失败: #{e.message}"
  end

  # 群推：推给所有在线用户
  # @param title [String] 通知标题
  # @param body [String] 通知内容
  # @param payload [Hash] 透传数据
  # @return [Hash] 个推返回结果
  def push_to_all(title, body, payload: {})
    message = build_notification_message(title, body, payload)
    Getui.push_app(message)
  rescue Getui::PushError, Getui::GenerateAuthTokenError => e
    Rails.logger.error("[GetuiService] push_to_all failed: #{e.class}: #{e.message}")
    raise PushError, "群推失败: #{e.message}"
  end

  # 查询用户在线状态
  # @param cid [String] 客户端 CID
  # @return [Hash] 个推返回结果
  def check_user_status(cid)
    Getui.user_status(cid)
  rescue StandardError => e
    Rails.logger.error("[GetuiService] user_status failed: #{e.class}: #{e.message}")
    raise PushError, "查询用户状态失败: #{e.message}"
  end

  private

  # 构建通知消息（Android 通知栏推送）
  def build_notification_message(title, body, payload)
    message = Getui::Message::Transmission.new(
      payload.to_json,
      is_offline: true,
      offline_expire_time: 24 * 60 * 60
    )
    message
  end
end
