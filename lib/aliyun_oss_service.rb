# frozen_string_literal: true

require "pathname"
require "securerandom"

class AliyunOssService
  class UploadError < StandardError; end

  def initialize(bucket: nil)
    @bucket = bucket || OSS_BUCKET
  end

  # 上传本地文件到 OSS
  # @param local_path [String, Pathname] 本地文件路径
  # @param object_key [String] OSS 中的对象路径（如 "epub-assets/images/page-1-image-1.png"）
  # @param content_type [String] MIME 类型，不传则根据文件名推断
  # @return [String] 上传后图片的公网 URL
  def upload_file(local_path:, object_key:, content_type: nil)
    local_path = Pathname.new(local_path.to_s)
    raise ArgumentError, "本地文件不存在: #{local_path}" unless local_path.exist?

    content_type ||= infer_content_type(local_path.basename.to_s)

    @bucket.put_object(
      object_key,
      file: local_path.to_s,
      content_type: content_type
    )

    public_url(object_key)
  rescue StandardError => e
    raise UploadError, "OSS 上传失败: #{e.message}"
  end

  # 上传二进制数据到 OSS
  # @param data [String] 二进制数据
  # @param object_key [String] OSS 中的对象路径
  # @param content_type [String] MIME 类型
  # @return [String] 上传后的公网 URL
  def upload_data(data:, object_key:, content_type: "application/octet-stream")
    @bucket.put_object(object_key, content_type: content_type) { |w| w.write(data) }

    public_url(object_key)
  rescue StandardError => e
    raise UploadError, "OSS 上传失败: #{e.message}"
  end

  # 从 OSS 下载文件到本地
  # @param object_key [String] OSS 中的对象路径
  # @param local_path [String, Pathname] 本地保存路径
  def download_file(object_key:, local_path:)
    local_path = Pathname.new(local_path.to_s)
    FileUtils.mkdir_p(local_path.dirname)

    @bucket.get_object(object_key, file: local_path.to_s)
    local_path
  rescue StandardError => e
    raise UploadError, "OSS 下载失败: #{e.message}"
  end

  # 生成公网 URL
  # @param object_key [String] OSS 对象路径
  # @return [String] 公网可访问 URL
  def public_url(object_key)
    "https://#{OSS_BUCKET_NAME}.#{OSS_ENDPOINT}/#{object_key}"
  end

  # 生成签名 URL（临时授权访问私有 bucket）
  # @param object_key [String] OSS 对象路径
  # @param expires [Integer] 过期时间（秒），默认 3600
  # @return [String] 签名 URL
  def generate_signed_url(object_key, expires: 3600)
    @bucket.object_url(object_key, true, expires)
  rescue StandardError => e
    raise UploadError, "OSS 签名失败: #{e.message}"
  end

  private

  def infer_content_type(filename)
    ext = File.extname(filename).downcase
    case ext
    when ".png" then "image/png"
    when ".jpg", ".jpeg" then "image/jpeg"
    when ".jpx" then "image/jpx"
    when ".gif" then "image/gif"
    when ".pdf" then "application/pdf"
    when ".epub" then "application/epub+zip"
    else "application/octet-stream"
    end
  end
end
