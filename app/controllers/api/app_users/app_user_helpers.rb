# frozen_string_literal: true

# AppUser 模块辅助方法
module Api
  module AppUsers
    module AppUserHelpers
      extend Grape::API::Helpers

      CODE_COOLDOWN = 60.seconds.freeze

      # 查找或注册用户
      def find_or_register_user(phone)
        default_head_img = HeadImg.normal.ordered.first
        AppUser.find_or_create_by!(phone: phone) do |u|
          u.nickname = '少年越读者'
          u.head_img_id = default_head_img&.id
        end
      end
    end
  end
end
