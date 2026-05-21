# frozen_string_literal: true

module Entities
  class ParentalControl < Grape::Entity
    expose :time_limit_minutes
    expose :time_limit_label do |instance, _|
      case instance.time_limit_minutes
      when 30 then '30分钟'
      when 60 then '60分钟'
      when 90 then '90分钟'
      else '无限制'
      end
    end
    expose :phone
    expose :phone_masked do |instance, _|
      instance.phone.blank? ? '' : "#{instance.phone[0..2]}****#{instance.phone[7..]}"
    end
    expose :blacklist_count do |instance, _|
      instance.blacklisted_books.count
    end
    expose :is_active
  end
end
