# == Schema Information
#
# Table name: sms_verifications
#
#   id                   integer(8)         not null, primary key
#   phone                string(255)        not null
#   code                 string(255)        not null
#   verified             boolean            not null, default(0)
#   expires_at           datetime           not null
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_sms_verifications_on_phone_and_code on phone, code
#  Index: index_sms_verifications_on_expires_at on expires_at
#
#
# frozen_string_literal: true

# 短信验证码模型
# 管理用户登录/注册时的短信验证码
class SmsVerification < ApplicationRecord
  # 验证规则
  validates :phone, presence: true,
                    format: { with: /\A1[3-9]\d{9}\z/, message: "手机号格式不正确" }
  validates :code, presence: true, length: { is: 4 } # 4位验证码
  validates :expires_at, presence: true

  # 作用域
  scope :valid_codes, -> { where(verified: false).where("expires_at > ?", Time.current) }
  scope :sent_recently_for, ->(phone, cooldown = 60.seconds) { where(phone: phone).where("created_at > ?", cooldown.ago) }
  scope :for_phone, ->(phone) { where(phone: phone) }
  scope :by_code, ->(code) { where(code: code) }

  # 验证码是否过期
  def expired?
    expires_at < Time.current
  end

  # 标记为已验证
  def mark_verified!
    update!(verified: true)
  end
end
