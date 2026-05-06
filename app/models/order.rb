# frozen_string_literal: true

# 订单模型
# 管理用户的购买订单（支持支付宝和微信支付）
class Order < ApplicationRecord
  # 支付方式枚举
  enum :payment_method, { alipay: 0, wechat: 1 }, default: :alipay

  # 状态枚举
  enum :status, { pending: 0, paid: 1, failed: 2, refunded: 3 }, default: :pending

  # 关联关系
  belongs_to :app_user, class_name: "AppUser"    # 所属用户
  belongs_to :membership, optional: true        # 关联会员

  # 验证规则
  validates :order_no, presence: true, uniqueness: true  # 订单号必填且唯一
  validates :amount, presence: true, numericality: { greater_than: 0 }

  # 创建前自动生成订单号
  before_validation :generate_order_no, on: :create

  # 标记为已支付
  def mark_paid!
    update!(status: :paid, paid_at: Time.current)
  end

  private

  # 生成唯一订单号（时间戳+随机数）
  def generate_order_no
    self.order_no ||= "VB#{Time.current.strftime('%Y%m%d%H%M%S')}#{SecureRandom.hex(4).upcase}"
  end
end
