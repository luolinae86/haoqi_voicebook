# frozen_string_literal: true

# 加载 .env 文件（开发环境）
if Rails.env.development? || Rails.env.test?
  env_path = Rails.root.join(".env")
  if env_path.exist?
    env_path.readlines.each do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      key, value = line.split("=", 2)
      ENV[key.strip] ||= value.strip
    end
  end
end

require "aliyun/oss"
require "aliyun/sts"

OSS_BUCKET_NAME = ENV.fetch("OSS_BUCKET_NAME", "epub-files")
OSS_ENDPOINT = ENV.fetch("OSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com")
OSS_ACCESS_KEY_ID = ENV.fetch("ALIYUN_ACCESS_KEY_ID")
OSS_ACCESS_KEY_SECRET = ENV.fetch("ALIYUN_ACCESS_KEY_SECRET")
OSS_STS_ROLE_ARN = ENV.fetch("OSS_STS_ROLE_ARN")

OSS_CLIENT = Aliyun::OSS::Client.new(
  endpoint: "https://#{OSS_ENDPOINT}",
  access_key_id: OSS_ACCESS_KEY_ID,
  access_key_secret: OSS_ACCESS_KEY_SECRET
)

OSS_BUCKET = OSS_CLIENT.get_bucket(OSS_BUCKET_NAME)