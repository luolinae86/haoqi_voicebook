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

        # 尝试标准 URI 解析，若包含非 ASCII 字符则用正则提取
        begin
          uri = URI.parse(url)
          host_parts = uri.host.to_s.split(".", 2)
          return url if host_parts.size < 2 || host_parts.first.empty? || host_parts.last.empty?
          object_key = uri.path.sub(/\A\//, "")
        rescue URI::InvalidURIError
          # 非 ASCII URL（如含中文），用正则提取
          if url =~ %r{\Ahttps?://([^/]+)(/.*)?\z}
            host_parts = $1.split(".", 2)
            return url if host_parts.size < 2 || host_parts.first.empty? || host_parts.last.empty?
            object_key = ($2 || "/").sub(/\A\//, "")
          else
            return url
          end
        end

        bucket_name = host_parts.first
        endpoint = host_parts.last
        object_key = CGI.unescape(object_key)

        # 手动生成签名（使用 URL 中的实际 bucket，而非配置常量）
        expires_at = Time.now.to_i + expires
        canonicalized_resource = "/#{bucket_name}/#{object_key}"
        string_to_sign = "GET\n\n\n#{expires_at}\n#{canonicalized_resource}"

        signature = Base64.strict_encode64(
          OpenSSL::HMAC.digest("sha1", OSS_ACCESS_KEY_SECRET, string_to_sign)
        )

        query = "Expires=#{expires_at}&OSSAccessKeyId=#{OSS_ACCESS_KEY_ID}&Signature=#{CGI.escape(signature)}"
        "https://#{bucket_name}.#{endpoint}/#{CGI.escape(object_key)}?#{query}"
      rescue StandardError
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
