# == Schema Information
#
# Table name: memberships
#
#   id                   integer(8)         not null, primary key
#   app_user_id          integer(4)         not null
#   plan_type            integer(4)         not null, default(0)
#   price                decimal            not null
#   original_price       decimal
#   start_date           date               not null
#   end_date             date               not null
#   status               integer(4)         not null, default(0)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_memberships_on_app_user_id on app_user_id
#  Index: index_memberships_on_status on status
#  Index: index_memberships_on_end_date on end_date
#
#
# frozen_string_literal: true

# 会员模型
# 管理用户的 VIP 会员订阅（年度、季度、月度会员）
class Membership < ApplicationRecord
  # 套餐类型枚举
  enum :plan_type, { monthly: 0, quarterly: 1, annual: 2 }, default: :monthly

  # 状态枚举
  enum :status, { pending: 0, active: 1, expired: 2, cancelled: 3 }, default: :pending

  # 关联关系
  belongs_to :app_user, class_name: "AppUser" # 所属用户
  has_many :orders, dependent: :nullify # 关联订单

  # 验证规则
  validates :plan_type, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :original_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  # 作用域
  scope :active_memberships, -> { where(status: :active).where("end_date >= ?", Date.current) }

  # 检查会员是否有效
  def active?
    status == "active" && end_date >= Date.current
  end

  # 会员套餐时长（天）
  def duration_days
    (end_date - start_date).to_i
  end

  # 套餐中文名称
  PLAN_LABELS = { monthly: "月度会员", quarterly: "季度会员", annual: "年度会员" }.freeze

  def plan_label
    PLAN_LABELS[plan_type.to_sym]
  end

  # 会员套餐价格配置（单位：元）
  PLAN_PRICES = {
    monthly: { price: 19.90, original_price: 29.90 },
    quarterly: { price: 49.90, original_price: 89.70 },
    annual: { price: 168.00, original_price: 358.80 }
  }.freeze

  def self.plan_info(plan_type)
    PLAN_PRICES[plan_type.to_sym]
  end
end
