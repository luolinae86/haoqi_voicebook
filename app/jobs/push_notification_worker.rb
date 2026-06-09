# frozen_string_literal: true

# 个推推送异步任务
# 使用 Sidekiq 异步执行推送，避免阻塞 API 响应
#
# 用法：
#   # 单推
#   PushNotificationWorker.perform_async(
#     cid: "xxx",
#     title: "新内容上线",
#     body: "《xxx》已上架，快来看看吧！"
#   )
#
#   # 批量推
#   PushNotificationWorker.perform_async(
#     cid_list: ["xxx", "yyy"],
#     title: "新内容上线",
#     body: "《xxx》已上架，快来看看吧！"
#   )
#
#   # 全推
#   PushNotificationWorker.perform_async(
#     all: true,
#     title: "系统通知",
#     body: "系统维护通知"
#   )
class PushNotificationWorker
  include Sidekiq::Job

  sidekiq_options queue: 'push', retry: 2

  # @param args [Hash] 必须使用 Hash with string keys（Sidekiq 7 JSON 序列化要求）
  #   :cid        [String]        单个 CID（单推）
  #   :cid_list   [Array<String>] CID 列表（批量推）
  #   :all        [Boolean]       是否全推
  #   :title      [String]        通知标题
  #   :body       [String]        通知内容
  #   :payload    [Hash]          透传数据（可选）
  def perform(args)
    args = args.symbolize_keys
    title = args[:title]
    body = args[:body]
    payload = args[:payload] || {}

    raise ArgumentError, 'title 不能为空' if title.blank?
    raise ArgumentError, 'body 不能为空' if body.blank?

    service = GetuiService.new

    if args[:all] == true
      result = service.push_to_all(title, body, payload: payload)
      Rails.logger.info("[PushNotification] push_to_all: title=#{title}, result=#{result}")
    elsif args[:cid_list].present?
      results = service.push_to_batch(args[:cid_list], title, body, payload: payload)
      Rails.logger.info("[PushNotification] push_to_batch: count=#{results.size}")
    elsif args[:cid].present?
      result = service.push_to_single(args[:cid], title, body, payload: payload)
      Rails.logger.info("[PushNotification] push_to_single: cid=#{args[:cid]}, result=#{result}")
    else
      raise ArgumentError, '必须指定 cid、cid_list 或 all 之一'
    end
  rescue GetuiService::PushError => e
    Rails.logger.error("[PushNotification] PushError: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("[PushNotification] Failed: #{e.class}: #{e.message}")
    raise
  end
end
