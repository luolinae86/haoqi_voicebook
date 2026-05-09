# == Schema Information
#
# Table name: app_users
#
#   id                   integer(8)         not null, primary key
#   phone                string(255)
#   password_digest      string(255)
#   nickname             string(255)
#   avatar               string(255)
#   grade_id             integer(4)
#   role                 integer(4)         not null, default(0)
#   reading_words        integer(4)         not null, default(0)
#   reading_minutes      integer(4)         not null, default(0)
#   books_read           integer(4)         not null, default(0)
#   is_vip               boolean            not null, default(0)
#   vip_expires_at       datetime
#   created_at           datetime           not null
#   updated_at           datetime           not null
#   device_id            string(64)
#   wechat_openid        string(255)
#   qq_openid            string(255)
#   uuid                 string(32)         not null
#
#  Index: index_app_users_on_phone on phone (unique)
#  Index: index_app_users_on_device_id on device_id (unique)
#  Index: index_app_users_on_wechat_openid on wechat_openid (unique)
#  Index: index_app_users_on_qq_openid on qq_openid (unique)
#  Index: index_app_users_on_grade_id on grade_id
#  Index: index_app_users_on_is_vip on is_vip
#  Index: index_app_users_on_uuid on uuid (unique)
#
#
# frozen_string_literal: true

# 用户模型
# 管理用户账户信息，支持手机号+验证码登录、密码登录、微信登录、QQ登录
class AppUser < ApplicationRecord
  self.table_name = "app_users"
  has_secure_password validations: false # 密码加密（可选密码）

  before_validation :generate_device_id, on: :create
  before_validation :generate_uuid

  validates :uuid, uniqueness: true

  # 用户角色枚举
  enum :role, { child: 0, parent: 1, admin: 2 }, default: :child

  # 关联关系
  has_many :bookshelves, dependent: :destroy # 用户书架
  has_many :shelf_books, through: :bookshelves, source: :book # 书架上的图书
  has_many :memberships, dependent: :destroy             # 会员记录
  has_many :orders, dependent: :destroy                  # 订单记录
  has_many :bookmarks, dependent: :destroy               # 书签
  has_one :parental_control, dependent: :destroy         # 家长管控

  # 验证规则
  validates :phone, uniqueness: true,
                    format: { with: /\A1[3-9]\d{9}\z/, message: "手机号格式不正确" },
                    allow_blank: true
  validates :wechat_openid, uniqueness: true, allow_blank: true
  validates :qq_openid, uniqueness: true, allow_blank: true
  validates :nickname, length: { maximum: 50 }, allow_blank: true

  # 作用域
  scope :vip_users, -> { where(is_vip: true).where("vip_expires_at > ?", Time.current) }

  # 检查用户是否为有效 VIP
  def vip_active?
    is_vip? && vip_expires_at.present? && vip_expires_at > Time.current
  end

  # 更新阅读统计
  def update_reading_stats!(words: 0, minutes: 0, books: 0)
    increment!(:reading_words, words) if words > 0
    increment!(:reading_minutes, minutes) if minutes > 0
    increment!(:books_read, books) if books > 0
  end

  private

  def generate_device_id
    self.device_id = SecureRandom.uuid.delete("-") if new_record? && device_id.blank?
  end

  def generate_uuid
    write_attribute(:uuid, SecureRandom.uuid.delete("-")) if new_record? || uuid.blank?
  end
end
