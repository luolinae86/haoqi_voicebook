# frozen_string_literal: true

# AppUser 模块辅助方法
module Api
  module AppUsers
    module AppUserHelpers
      extend Grape::API::Helpers

      CODE_COOLDOWN = 60.seconds.freeze

      # 查找或注册用户
      def find_or_register_user(phone)
        user = create_new_app_user
        user.update!(phone: phone)
        user
      end

      # 创建新用户（默认三年级、昵称、头像）
      # @param device_id [String, nil] 设备ID，传入时会自动绑定
      def create_new_app_user(device_id = nil)
        user = AppUser.create!(
          grade_id: Grade.find_by(name: '三年级')&.id,
          nickname: '少年越读者'
        )
        Device.bind!(device_id, user) if device_id

        default_head_img = HeadImg.normal.ordered.first
        user.update!(head_img_id: default_head_img.id) if default_head_img && user.head_img_id.blank?

        user
      end
    end
  end
end
