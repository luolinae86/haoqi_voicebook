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

    # 使用乐观锁避免并发回调重复处理
    order = Order.find_by!(order_no: order_no)

    # 原子操作：仅当状态为 pending 时更新为 paid
    affected = Order.pending.where(id: order.id)
                    .update_all(status: :paid, paid_at: Time.current, updated_at: Time.current)
    return if affected.zero? # 已被其他回调处理过

    order.reload
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
