# frozen_string_literal: true

# OSS URL 规范化：修复常见的 URL 格式错误
# - 移除重复的 oss- 前缀（oss-oss-cn-hangzhou → oss-cn-hangzhou）
# - 移除重复的域名后缀（.aliyuncs.com.aliyuncs.com → .aliyuncs.com）
module OssUrlNormalizable
  extend ActiveSupport::Concern

  # 规范化 OSS URL
  # @param url [String, nil] 原始 URL
  # @return [String, nil] 规范化后的 URL
  def self.normalize_oss_url(url)
    return url if url.blank?
    return url unless url.include?("aliyuncs.com")

    url
      .gsub(%r{oss-oss-}, "oss-")
      .gsub(%r{\.aliyuncs\.com\.aliyuncs\.com}, ".aliyuncs.com")
  end

  included do
    class_methods do
      # 声明需要规范化的 URL 字段
      def normalizes_oss_urls(*fields)
        before_save :normalize_oss_url_fields
        define_method(:oss_url_fields) { fields }
      end
    end
  end

  private

  def normalize_oss_url_fields
    return unless respond_to?(:oss_url_fields)

    oss_url_fields.each do |field|
      value = send(field)
      next if value.blank?

      normalized = OssUrlNormalizable.normalize_oss_url(value)
      send("#{field}=", normalized) if normalized != value
    end
  end
end
