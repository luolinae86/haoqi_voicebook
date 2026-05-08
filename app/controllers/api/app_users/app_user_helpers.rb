# frozen_string_literal: true

# AppUser 模块辅助方法
module Api
  module AppUsers
    module AppUserHelpers
      extend Grape::API::Helpers

      PHONE_REGEXP = /\A1[3-9]\d{9}\z/.freeze
      CODE_EXPIRES_IN = 5.minutes.freeze
      CODE_COOLDOWN = 60.seconds.freeze
      CODE_LENGTH = 4

      # 验证手机号格式
      def validate_phone!(phone)
        error_pop_resp("手机号格式不正确") unless phone.match?(PHONE_REGEXP)
      end

      # 检查发送频率限制
      def check_send_rate_limit!(phone)
        sent_recently = SmsVerification.sent_recently_for(phone, CODE_COOLDOWN).exists?
        error_pop_resp("验证码已发送，请 60 秒后再试") if sent_recently
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

      # 查找并验证短信验证码
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

      # 查找或注册用户
      def find_or_register_user(phone)
        AppUser.find_or_create_by!(phone: phone) do |u|
          u.nickname = "用户#{phone[-4..]}"
        end
      end
    end
  end
end
