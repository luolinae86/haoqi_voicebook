# == Schema Information
#
# Table name: orders(订单表)
#
#  id                                              :bigint           not null, primary key
#  amount(金额)                                    :decimal(10, 2)   not null
#  order_no(订单号)                                :string(255)      not null
#  paid_at(支付时间)                               :datetime
#  payment_method(支付方式：0-支付宝 1-微信)       :integer          default("alipay"), not null
#  status(状态：0-待支付 1-已支付 2-失败 3-已退款) :integer          default("pending"), not null
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  app_user_id(用户ID)                             :integer          not null
#  membership_id(会员ID)                           :integer
#
# Indexes
#
#  index_orders_on_app_user_id    (app_user_id)
#  index_orders_on_membership_id  (membership_id)
#  index_orders_on_order_no       (order_no) UNIQUE
#  index_orders_on_status         (status)
#
# frozen_string_literal: true

# 订单模型
# 管理用户的购买订单（支持支付宝和微信支付）
class Order < ApplicationRecord
  # 支付方式枚举
  enum :payment_method, { alipay: 0, wechat: 1 }, default: :alipay

  # 状态枚举
  enum :status, { pending: 0, paid: 1, failed: 2, refunded: 3 }, default: :pending

  # 关联关系
  belongs_to :app_user, class_name: 'AppUser' # 所属用户
  belongs_to :membership, optional: true # 关联会员

  # 作用域
  scope :pending, -> { where(status: :pending) }
  scope :paid, -> { where(status: :paid) }
  scope :paid_with_membership, lambda { |user|
    joins(:membership)
      .where(app_user: user)
      .merge(paid)
      .includes(:membership)
      .order(created_at: :desc)
  }

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
  # 如果用户已是 VIP 且会员未过期，则在现有过期时间基础上延长
  def activate_membership!
    return unless membership

    new_end_date = calculate_end_date(membership.plan_type)

    # 如果用户当前是有效 VIP，在现有过期时间基础上延长
    if app_user.is_vip? && app_user.vip_expires_at.present? && app_user.vip_expires_at > Time.current
      base_date = app_user.vip_expires_at.to_date
      days = (new_end_date - Date.current).to_i
      new_end_date = base_date + days
    end

    membership.update!(
      status: :active,
      start_date: Date.current,
      end_date: new_end_date
    )

    app_user.update!(
      is_vip: true,
      vip_expires_at: new_end_date.end_of_day
    )

    Rails.logger.info("[Order] Activated #{membership.plan_type} membership for user ##{app_user_id}, ends at #{new_end_date}")
  end

  private

  def calculate_end_date(plan_type)
    case plan_type
    when 'monthly'   then 1.month.from_now.to_date
    when 'quarterly' then 3.months.from_now.to_date
    when 'annual'    then 1.year.from_now.to_date
    end
  end

  # 生成唯一订单号（时间戳+随机数）
  def generate_order_no
    self.order_no ||= "VB#{Time.current.strftime('%Y%m%d%H%M%S')}#{SecureRandom.hex(4).upcase}"
  end
end
