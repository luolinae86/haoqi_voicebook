# == Schema Information
#
# Table name: parental_controls(家长管控表)
#
#  id                                 :bigint           not null, primary key
#  is_active(是否启用)                :boolean          default(TRUE), not null
#  password_digest(家长密码)          :string(255)      not null
#  phone(家长手机号)                  :string(255)
#  time_limit_minutes(时间限制(分钟)) :integer
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  app_user_id(用户ID)                :integer          not null
#
# Indexes
#
#  index_parental_controls_on_app_user_id  (app_user_id) UNIQUE
#
# frozen_string_literal: true

# 家长管控模型
# 管理家长对孩子阅读的控制（密码、时间限制、内容黑名单）
class ParentalControl < ApplicationRecord
  has_secure_password # 家长密码加密

  # 关联关系
  belongs_to :app_user, class_name: "AppUser" # 关联用户
  has_many :blacklisted_books, dependent: :destroy # 黑名单图书

  # 验证规则
  validates :app_user_id, uniqueness: true # 每个用户只能有一个家长管控
  validates :time_limit_minutes, numericality: { greater_than: 0 }, allow_nil: true

  # 时间限制选项（分钟）
  TIME_LIMITS = [0, 30, 60, 90].freeze # 0 表示无限制
end
