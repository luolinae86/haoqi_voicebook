# frozen_string_literal: true
# 用户模型
# 管理用户账户信息，支持手机号+验证码登录和密码登录
class AppUser < ApplicationRecord
  self.table_name = "app_users"
  has_secure_password validations: false  # 密码加密（可选密码）

  before_validation :generate_device_id, on: :create

  # 用户角色枚举
  enum :role, { child: 0, parent: 1, admin: 2 }, default: :child

  # 关联关系
  belongs_to :grade, optional: true                     # 所属年级
  has_many :bookshelves, dependent: :destroy             # 用户书架
  has_many :shelf_books, through: :bookshelves, source: :book  # 书架上的图书
  has_many :reading_records, dependent: :destroy         # 阅读记录
  has_many :memberships, dependent: :destroy             # 会员记录
  has_many :orders, dependent: :destroy                  # 订单记录
  has_many :bookmarks, dependent: :destroy               # 书签
  has_one :parental_control, dependent: :destroy         # 家长管控

  # 验证规则
  validates :phone, uniqueness: true,
                    format: { with: /\A1[3-9]\d{9}\z/, message: "手机号格式不正确" },
                    allow_blank: true
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
end
