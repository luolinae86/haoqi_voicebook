# == Schema Information
#
# Table name: memberships(会员表)
#
#  id                                              :bigint           not null, primary key
#  end_date(结束日期)                              :date             not null
#  original_price(原价)                            :decimal(10, 2)
#  plan_type(套餐：0-月度 1-季度 2-年度)           :integer          default("monthly"), not null
#  price(实付价格)                                 :decimal(10, 2)   not null
#  start_date(开始日期)                            :date             not null
#  status(状态：0-待支付 1-有效 2-已过期 3-已取消) :integer          default("pending"), not null
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  app_user_id(用户ID)                             :integer          not null
#
# Indexes
#
#  index_memberships_on_app_user_id  (app_user_id)
#  index_memberships_on_end_date     (end_date)
#  index_memberships_on_status       (status)
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
  belongs_to :app_user, class_name: 'AppUser' # 所属用户
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
    status == 'active' && end_date >= Date.current
  end

  # 会员套餐时长（天）
  def duration_days
    (end_date - start_date).to_i
  end

  # 套餐中文名称
  PLAN_LABELS = { monthly: '月度会员', quarterly: '季度会员', annual: '年度会员' }.freeze

  def plan_label
    PLAN_LABELS[plan_type.to_sym]
  end

  # 根据套餐类型计算结束日期
  def self.calculate_end_date(plan_type)
    case plan_type.to_s
    when 'monthly'   then 1.month.from_now.to_date
    when 'quarterly' then 3.months.from_now.to_date
    when 'annual'    then 1.year.from_now.to_date
    end
  end
end
