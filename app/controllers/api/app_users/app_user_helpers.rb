# frozen_string_literal: true

# AppUser 模块辅助方法
module Api
  module AppUsers
    module AppUserHelpers
      extend Grape::API::Helpers

      CODE_COOLDOWN = 60.seconds.freeze

      # 查找或注册用户
      def find_or_register_user(phone)
        AppUser.find_or_create_by!(phone: phone) do |u|
          u.nickname = "用户#{phone[-4..]}"
        end
      end
    end
  end
end
