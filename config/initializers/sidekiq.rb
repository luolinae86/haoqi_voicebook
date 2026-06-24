# frozen_string_literal: true

require "fileutils"

# Sidekiq Redis 配置
# 使用 Application.build_redis_url 统一构建
sidekiq_url = Rails.application.class.build_redis_url

Sidekiq.configure_server do |config|
  config.redis = { url: sidekiq_url }

  # 持久化日志到 log/sidekiq.log（按天轮转），同时输出到 stdout
  log_path = Rails.root.join("log/sidekiq.log")
  FileUtils.mkdir_p(log_path.dirname)
  config.logger = Logger.new(log_path.to_s, "daily")
  config.logger.level = ::Logger::INFO

  # 定时任务（从 config/sidekiq.yml :schedule 加载）
  schedule_file = Rails.root.join("config/sidekiq.yml")
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(schedule_file, aliases: true)["schedule"] || {})
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: sidekiq_url }
end
