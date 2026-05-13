# frozen_string_literal: true

# OSS 模块辅助方法
module Api
  module Oss
    module OssHelpers
      extend Grape::API::Helpers

      # 生成 OSS 对象签名 URL（临时授权访问私有 bucket）
      # @param object_key [String] OSS 对象路径
      # @param expires [Integer] 过期时间（秒），默认 3600
      # @return [String] 签名 URL
      def generate_oss_signed_url(object_key, expires: 3600)
        oss_service = AliyunOssService.new
        oss_service.generate_signed_url(object_key, expires: expires)
      rescue AliyunOssService::UploadError => e
        error!({ response: { code: 1, msg: e.message, data: nil } }, 200)
      end
    end
  end
end
