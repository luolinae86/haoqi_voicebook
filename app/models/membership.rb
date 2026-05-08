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
end
