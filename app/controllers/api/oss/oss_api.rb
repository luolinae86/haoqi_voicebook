# frozen_string_literal: true

module Api
  module Oss
    class OssApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Oss::OssHelpers

      namespace :oss do
        # ==================== 获取签名 URL ====================
        desc "获取 OSS 对象的签名 URL（临时授权访问私有 bucket）"
        params do
          requires :uuid, type: String, desc: "用户uuid"
          requires :object_key, type: String, desc: "OSS 对象路径"
          optional :expires, type: Integer, desc: "过期时间（秒），默认3600", default: 3600
        end
        get :signed_url do
          auth_user

          signed_url = generate_oss_signed_url(params[:object_key], expires: params[:expires] || 3600)

          present response: success_response(signed_url: signed_url)
        end
      end
    end
  end
end
