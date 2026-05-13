# frozen_string_literal: true

module Api
  module Oss
    class OssApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Oss::OssHelpers

      namespace :oss do
        desc "获取 OSS 临时授权凭证（STSToken）"
        params do
          requires :uuid, type: String, desc: "用户uuid"
        end
        get :token do
          auth_user

          info = oss_token(OSS_ENDPOINT, OSS_BUCKET_NAME)

          present response: success_response(info: info)
        end
      end
    end
  end
end
