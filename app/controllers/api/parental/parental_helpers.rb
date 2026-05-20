# frozen_string_literal: true

# 家长管控模块辅助方法
module Api
  module Parental
    module ParentalHelpers
      extend Grape::API::Helpers

      # 时间限制显示标签
      def time_limit_label(minutes)
        case minutes
        when 30 then '30分钟'
        when 60 then '60分钟'
        when 90 then '90分钟'
        else '无限制'
        end
      end

      # 手机号脱敏显示
      def mask_phone(phone)
        return '' if phone.blank?

        "#{phone[0..2]}****#{phone[7..]}"
      end
    end
  end
end
