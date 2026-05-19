# frozen_string_literal: true

# 用户头像 API
module Api
  module HeadImgs
    class HeadImgApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :head_imgs do
        # ==================== 头像列表 ====================
        desc '获取全部可用头像列表（根据 VIP 状态过滤，需 uuid 鉴权）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :index do
          auth_user

          imgs = current_user.vip_active? ? HeadImg.all : HeadImg.normal
          present response: success_response(
            head_imgs: serialize_collection(imgs.ordered, Entities::HeadImg)
          )
        end
      end
    end
  end
end
