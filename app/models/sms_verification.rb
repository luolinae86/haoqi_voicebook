# frozen_string_literal: true

# 短信验证码模型
# 管理用户登录/注册时的短信验证码
class SmsVerification < ApplicationRecord
  # 验证规则
  validates :phone, presence: true,
                    format: { with: /\A1[3-9]\d{9}\z/, message: "手机号格式不正确" }
  validates :code, presence: true, length: { is: 4 }  # 4位验证码
  validates :expires_at, presence: true

  # 作用域
  scope :valid_codes, -> { where(verified: false).where("expires_at > ?", Time.current) }

  # 验证码是否过期
  def expired?
    expires_at < Time.current
  end

  # 标记为已验证
  def mark_verified!
    update!(verified: true)
  end
end
