# frozen_string_literal: true

require "aliyun/sts"

# OSS 模块辅助方法
module Api
  module Oss
    module OssHelpers
      extend Grape::API::Helpers

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
