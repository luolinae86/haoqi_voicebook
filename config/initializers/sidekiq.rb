# frozen_string_literal: true

require "uri"
require "fileutils"

# Sidekiq Redis 配置
# 本地开发/测试：使用本地 Redis (localhost:6379)
# 线上生产：使用阿里云 Redis (REDIS_URL + REDIS_PASSWORD)
def build_sidekiq_redis_url
  # 本地环境直接用本地 Redis
  if Rails.env.development? || Rails.env.test?
    return "redis://localhost:6379/0"
  end

  # 生产环境：阿里云 Redis
  host = ENV.fetch("REDIS_URL", nil)
  password = ENV.fetch("REDIS_PASSWORD", nil)
  return "redis://localhost:6379/0" unless host

  # 已经是完整 URL
  return host if host.start_with?("redis://")

  # 拼装: redis://:password@host:6379/0
  host_without_scheme = host.sub(%r{^https?://}, "")
  port_match = host_without_scheme.match(/:(\d+)$/)
  port = port_match ? port_match[1] : "6379"
  host_part = port_match ? host_without_scheme.sub(/:\d+$/, "") : host_without_scheme
  host_part = host_part.sub(%r{/$}, "")

  "redis://#{password ? ":#{password}@" : ""}#{host_part}:#{port}/0"
end

sidekiq_url = build_sidekiq_redis_url

Sidekiq.configure_server do |config|
  config.redis = { url: sidekiq_url }

  if Rails.env.production?
    # 生产环境：输出到 stdout，方便 kamal app logs / docker logs 查看
    config.logger = Sidekiq::Logger.new($stdout)
    config.logger.level = ::Logger::INFO
  else
    # 开发环境：输出到文件
    log_path = Rails.root.join("log/sidekiq.log")
    FileUtils.mkdir_p(log_path.dirname)
    config.logger = Sidekiq::Logger.new(log_path.to_s)
    config.logger.level = ::Logger::INFO
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: sidekiq_url }
end
