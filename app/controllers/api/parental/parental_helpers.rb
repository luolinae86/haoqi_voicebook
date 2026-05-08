# frozen_string_literal: true

# 家长管控模块辅助方法
module Api
  module Parental
    module ParentalHelpers
      extend Grape::API::Helpers

      PHONE_REGEXP = /\A1[3-9]\d{9}\z/.freeze
      CODE_EXPIRES_IN = 5.minutes.freeze

      # 验证手机号格式
      def validate_phone!(phone)
        error_pop_resp("手机号格式不正确") unless phone.match?(PHONE_REGEXP)
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

      # 时间限制显示标签
      def time_limit_label(minutes)
        case minutes
        when 30 then "30分钟"
        when 60 then "60分钟"
        when 90 then "90分钟"
        else "无限制"
        end
      end

      # 手机号脱敏显示
      def mask_phone(phone)
        return "" if phone.blank?

        "#{phone[0..2]}****#{phone[7..]}"
      end
    end
  end
end
