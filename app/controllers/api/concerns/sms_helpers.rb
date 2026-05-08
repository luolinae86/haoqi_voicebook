# frozen_string_literal: true

# 短信服务通用辅助方法
# 封装手机号验证、验证码生成发送、验证码校验等通用逻辑
module Api
  module Concerns
    module SmsHelpers
      extend Grape::API::Helpers

      PHONE_REGEXP = /\A1[3-9]\d{9}\z/
      CODE_EXPIRES_IN = 5.minutes.freeze
      CODE_LENGTH = 4

      # 验证手机号格式
      def validate_phone!(phone)
        error_pop_resp("手机号格式不正确") unless phone.match?(PHONE_REGEXP)
      end

      # 生成随机验证码
      def generate_code
        rand(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")
      end

      # 创建并发送验证码
      def create_and_send_code(phone)
        code = generate_code
        SmsVerification.create!(phone: phone, code: code, expires_at: CODE_EXPIRES_IN.from_now)
        AliyunSmsService.new.send_verification_code(phone, code)
      end

      # 检查发送频率限制
      # @param cooldown [ActiveSupport::Duration] 冷却时间，默认 60 秒
      def check_send_rate_limit!(phone, cooldown: 60.seconds)
        sent_recently = SmsVerification.sent_recently_for(phone, cooldown).exists?
        error_pop_resp("验证码已发送，请 60 秒后再试") if sent_recently
      end

      # 查找并验证短信验证码（消费型，验证后标记为已使用）
      def find_and_consume_verification(phone, code)
        verification = SmsVerification.valid_codes
                                      .for_phone(phone)
                                      .by_code(code)
                                      .order(created_at: :desc)
                                      .first
        error_pop_resp("验证码无效或已过期") unless verification

        verification.mark_verified!
        verification
      end
    end
  end
end
