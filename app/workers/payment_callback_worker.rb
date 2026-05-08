# frozen_string_literal: true

# 支付回调处理异步任务
# 处理支付宝/微信支付异步通知，验证签名后激活会员
class PaymentCallbackWorker
  include Sidekiq::Job

  sidekiq_options queue: "payment", retry: 3

  # @param args [Hash] {"order_no" => String, "payment_method" => String, "result" => Hash}
  def perform(args)
    args = args.symbolize_keys
    order_no = args[:order_no]
    payment_method = args[:payment_method]
    args[:result]

    order = Order.find_by!(order_no: order_no)
    return if order.paid? # 防止重复处理

    order.mark_paid!
    order.activate_membership!

    Rails.logger.info("[PaymentCallback] #{payment_method} payment confirmed for order ##{order_no}")
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[PaymentCallback] Order not found: #{order_no}")
    raise
  rescue StandardError => e
    Rails.logger.error("[PaymentCallback] Failed for order ##{order_no}: #{e.class}: #{e.message}")
    raise
  end
end
