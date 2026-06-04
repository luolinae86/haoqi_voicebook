# == Schema Information
#
# Table name: sms_verifications(短信验证码表)
#
#  id                   :bigint           not null, primary key
#  code(验证码)         :string(255)      not null
#  expires_at(过期时间) :datetime         not null
#  phone(手机号)        :string(255)      not null
#  verified(是否已验证) :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_sms_verifications_on_expires_at      (expires_at)
#  index_sms_verifications_on_phone_and_code  (phone,code)
#
# frozen_string_literal: true

# 短信验证码模型
# 管理用户登录/注册时的短信验证码
class SmsVerification < ApplicationRecord
  # 验证规则
  validates :phone, presence: true,
                    format: { with: /\A1[3-9]\d{9}\z/, message: '手机号格式不正确' }
  validates :code, presence: true, length: { is: 4 } # 4位验证码
  validates :expires_at, presence: true

  # 作用域
  scope :valid_codes, -> { where(verified: false).where('expires_at > ?', Time.current) }
  scope :sent_recently_for, ->(phone, cooldown = 60.seconds) { where(phone: phone).where('created_at > ?', cooldown.ago) }
  scope :sent_today_for, ->(phone) { where(phone: phone).where('created_at >= ?', Time.current.beginning_of_day) }
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
