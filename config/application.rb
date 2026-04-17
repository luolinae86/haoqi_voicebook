require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Voicebook
  class Application < Rails::Application
    config.load_defaults 8.0

    # 自动加载 lib 目录
    config.autoload_lib(ignore: %w[assets tasks])

    # 设置默认语言为中文
    config.i18n.default_locale = :"zh-CN"

    # 设置时区为北京时间
    config.time_zone = "Beijing"

    # API-only 模式
    config.api_only = true

    # 默认分页数量
    config.x.default_per_page = 10

    # CORS 跨域配置
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "*",
          headers: :any,
          methods: %i[get post put patch delete options head],
          expose: %w[X-Total-Count X-Total-Pages X-Current-Page X-Per-Page]
      end
    end
  end
end
