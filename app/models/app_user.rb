# == Schema Information
#
# Table name: app_users(用户表)
#
#  id                                 :bigint           not null, primary key
#  avatar(头像URL)                    :string(255)
#  books_read(读过的书(本))           :integer          default(0), not null
#  is_vip(是否VIP)                    :boolean          default(FALSE), not null
#  nickname(昵称)                     :string(255)
#  password_digest(加密密码)          :string(255)
#  phone(手机号)                      :string(255)
#  qq_openid(QQ openid)               :string(255)
#  reading_minutes(阅读时长(分钟))    :integer          default(0), not null
#  reading_words(阅读字数)            :integer          default(0), not null
#  role(角色：0-孩子 1-家长 2-管理员) :integer          default("child"), not null
#  uuid                               :string(255)      not null
#  vip_expires_at(VIP过期时间)        :datetime
#  wechat_openid(微信openid)          :string(255)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  device_id                          :string(64)
#  grade_id(年级ID)                   :bigint
#
# Indexes
#
#  index_app_users_on_device_id      (device_id) UNIQUE
#  index_app_users_on_grade_id       (grade_id)
#  index_app_users_on_is_vip         (is_vip)
#  index_app_users_on_phone          (phone) UNIQUE
#  index_app_users_on_qq_openid      (qq_openid) UNIQUE
#  index_app_users_on_uuid           (uuid) UNIQUE
#  index_app_users_on_wechat_openid  (wechat_openid) UNIQUE
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
  has_many :devices, dependent: :destroy # 设备绑定（一个账户可绑定多个设备）
  has_many :bookshelves, dependent: :destroy # 用户书架
  has_many :shelf_books, through: :bookshelves, source: :book # 书架上的图书
  has_many :memberships, dependent: :destroy             # 会员记录
  has_many :orders, dependent: :destroy                  # 订单记录
  has_many :bookmarks, dependent: :destroy               # 书签
  has_one :parental_control, dependent: :destroy         # 家长管控
  has_many :reading_sessions, dependent: :destroy        # 阅读记录
  has_many :reading_progresses, dependent: :destroy      # 阅读进度
  has_many :user_reading_daily_stats, class_name: 'UserReadingDailyStats', dependent: :destroy # 日统计
  belongs_to :head_img, optional: true

  # 验证规则
  validates :phone, uniqueness: true,
                    format: { with: /\A1[3-9]\d{9}\z/, message: "手机号格式不正确" },
                    allow_blank: true
  validates :wechat_openid, uniqueness: true, allow_blank: true
  validates :qq_openid, uniqueness: true, allow_blank: true
  validates :nickname, length: { maximum: 50 }, allow_blank: true

  # 更新后清除缓存（包括 console 中的 update，跨 Redis 容器生效）
  after_commit :expire_cache, on: :update

  # 作用域
  scope :vip_users, -> { where(is_vip: true).where("vip_expires_at > ?", Time.current) }

  # 检查用户是否为有效 VIP
  def vip_active?
    is_vip? && vip_expires_at.present? && vip_expires_at > Time.current
  end

  # 获取当前设备ID（优先从 devices 表，回退到旧字段兼容）
  def device_id
    devices.order(:created_at).last&.device_id || super
  end

  # 更新阅读统计
  def update_reading_stats!(words: 0, minutes: 0, books: 0)
    increment!(:reading_words, words) if words > 0
    increment!(:reading_minutes, minutes) if minutes > 0
    increment!(:books_read, books) if books > 0
  end

  # 计算连续阅读天数
  def consecutive_reading_days
    return 0 if user_reading_daily_stats.empty?

    today = Date.today
    dates = user_reading_daily_stats.up_to_date(today)
                                     .pluck(:stat_date).map(&:to_date).sort.reverse

    return 0 if dates.empty?

    days = 1
    (1...dates.size).each do |i|
      if dates[i - 1] - dates[i] == 1
        days += 1
      else
        break
      end
    end

    # 如果最近一天不是今天或昨天，说明断了
    days = 0 if dates.first < today - 1
    days
  end

  # 获取阅读统计摘要
  def reading_stats_summary
    {
      total_reading_minutes: reading_minutes,
      total_books_read: books_read,
      total_words_read: reading_words,
      consecutive_days: consecutive_reading_days
    }
  end

  private

  def expire_cache
    Rails.cache.delete("app_user_#{uuid}")
  end

  def generate_device_id
    self.device_id = SecureRandom.uuid.delete("-") if new_record? && device_id.blank?
  end

  def generate_uuid
    self[:uuid] = SecureRandom.uuid.delete("-") if new_record? || uuid.blank?
  end
end
