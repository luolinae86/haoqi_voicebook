# frozen_string_literal: true

# 用户头像 API
module Api
  module HeadImgs
    class HeadImgApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :head_imgs do
        # ==================== 获取头像 ====================
        desc '获取用户头像（根据 VIP 状态返回不同头像，需 uuid 鉴权）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :random do
          auth_user

          head_img = HeadImg.random_for(vip: current_user.is_vip?)
          if head_img
            present response: success_response(head_img: Entities::HeadImg.represent(head_img).as_json)
          else
            present response: success_response(head_img: nil)
          end
        end

        # ==================== 头像列表 ====================
        desc '获取全部可用头像列表（根据 VIP 状态过滤，需 uuid 鉴权）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :index do
          auth_user

          imgs = current_user.is_vip? ? HeadImg.all : HeadImg.normal
          present response: success_response(
            head_imgs: serialize_collection(imgs.ordered, Entities::HeadImg)
          )
        end
      end
    end
  end
end
