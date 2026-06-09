# frozen_string_literal: true

# 个推推送配置
GE_TUI_APP_ID = ENV.fetch('GE_TUI_APP_ID', nil)
GE_TUI_APP_KEY = ENV.fetch('GE_TUI_APP_KEY', nil)
GE_TUI_MASTER_SECRET = ENV.fetch('GE_TUI_MASTER_SECRET', nil)

# 初始化个推 SDK（模块级别配置，SDK 内部会缓存 auth_token）
if GE_TUI_APP_ID && GE_TUI_APP_KEY && GE_TUI_MASTER_SECRET
  require 'getui'

  Getui.app_id = GE_TUI_APP_ID
  Getui.app_key = GE_TUI_APP_KEY
  Getui.master_secret = GE_TUI_MASTER_SECRET

  # 使用 Rails.cache 缓存 auth_token（避免频繁请求）
  Getui.cache_backend = Rails.cache if defined?(Rails)
end
