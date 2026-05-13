# frozen_string_literal: true

require "aliyun/sts"

# OSS 模块辅助方法
module Api
  module Oss
    module OssHelpers
      extend Grape::API::Helpers

      # 将 OSS 公网 URL 转换为临时签名 URL（私有 bucket 适用）
      # @param url [String, nil] OSS 对象 URL，如 "https://bucket.endpoint/object_key"
      # @param expires [Integer] 过期时间（秒），默认 3600
      # @return [String, nil] 签名 URL，若原 url 为空则返回 nil
      def signed_oss_url(url, expires: 3600)
        return nil if url.blank?

        # 从完整 URL 中提取 object_key
        # 格式: https://#{bucket}.#{endpoint}/#{object_key}
        uri = URI.parse(url)
        object_key = uri.path.sub(/\A\//, "") # 去掉前导 /

        oss_service = AliyunOssService.new
        oss_service.generate_signed_url(object_key, expires: expires)
      rescue URI::InvalidURIError, StandardError
        # 若解析失败，原样返回
        url
      end

      # 获取 OSS STS 临时授权 token
      # @param end_point [String] OSS 区域端点，如 "oss-cn-beijing"
      # @param bucket [String] bucket 名称
      # @return [Hash] STS 临时凭证
      def oss_token(end_point, bucket)
        sts = ::Aliyun::STS::Client.new(
          access_key_id: OSS_ACCESS_KEY_ID,
          access_key_secret: OSS_ACCESS_KEY_SECRET
        )

        token = sts.assume_role(OSS_STS_ROLE_ARN, "voicebook-oss-#{Time.now.to_i}")
        {
          end_point: end_point,
          bucket: bucket,
          access_key_id: token.access_key_id,
          access_key_secret: token.access_key_secret,
          security_token: token.security_token,
          expiration: token.expiration.to_s,
          session_name: token.session_name
        }
      end
    end
  end
end
