# frozen_string_literal: true

# 路由配置
# 挂载 Grape API 到 /api 路径
Rails.application.routes.draw do
  # 健康检查（用于负载均衡和 Docker）
  get "up" => "rails/health#show", as: :rails_health_check

  # 挂载 Grape API
  mount Api::Base => "/api"

  # 根路由 - Hello World 欢迎页
  root to: proc {
    [200, { "Content-Type" => "text/html; charset=utf-8" }, [
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>VoiceBook</title></head>
        <body style="font-family: Arial, sans-serif; text-align: center; padding-top: 100px;">
          <h1>🎧 Hello World!</h1>
          <p>VoiceBook API 项目创建成功！</p>
          <p>API 接口地址: <a href="/api">/api</a></p>
          <p>版本: 1.0.0 | Ruby #{RUBY_VERSION} | Rails #{Rails.version}</p>
        </body>
        </html>
      HTML
    ]]
  }
end
