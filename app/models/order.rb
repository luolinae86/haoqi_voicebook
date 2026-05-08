# frozen_string_literal: true

# 订单模型
# 管理用户的购买订单（支持支付宝和微信支付）
class Order < ApplicationRecord
  # 支付方式枚举
  enum :payment_method, { alipay: 0, wechat: 1 }, default: :alipay

  # 状态枚举
  enum :status, { pending: 0, paid: 1, failed: 2, refunded: 3 }, default: :pending

  # 关联关系
  belongs_to :app_user, class_name: "AppUser" # 所属用户
  belongs_to :membership, optional: true # 关联会员

  # 验证规则
  validates :order_no, presence: true, uniqueness: true # 订单号必填且唯一
  validates :amount, presence: true, numericality: { greater_than: 0 }

  # 创建前自动生成订单号
  before_validation :generate_order_no, on: :create

  # 标记为已支付
  def mark_paid!
    update!(status: :paid, paid_at: Time.current)
  end

  # 激活会员（订单支付成功后调用）
  def activate_membership!
    return unless membership

    membership.update!(
      status: :active,
      start_date: Date.current,
      end_date: calculate_end_date(membership.plan_type)
    )

    app_user.update!(
      is_vip: true,
      vip_expires_at: calculate_end_date(membership.plan_type).end_of_day
    )

    Rails.logger.info("[Order] Activated #{membership.plan_type} membership for user ##{app_user_id}")
  end

  private

  def calculate_end_date(plan_type)
    case plan_type
    when "monthly"   then 1.month.from_now.to_date
    when "quarterly" then 3.months.from_now.to_date
    when "annual"    then 1.year.from_now.to_date
    end
  end

  # 生成唯一订单号（时间戳+随机数）
  def generate_order_no
    self.order_no ||= "VB#{Time.current.strftime('%Y%m%d%H%M%S')}#{SecureRandom.hex(4).upcase}"
  end
end
