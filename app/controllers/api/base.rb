# frozen_string_literal: true

# API 基础入口
# 挂载所有 API 模块，提供健康检查接口
module Api
  class Base < Default
    # 引入通用辅助方法
    helpers Api::Helpers::CommonHelpers

    # ==================== 健康检查 ====================

    # 健康检查接口，用于负载均衡和 Docker 健康检查
    desc "健康检查接口"
    get :up do
      { code: 0, message: "VoiceBook API is running!", data: { status: "ok", time: Time.current.strftime("%Y-%m-%d %H:%M:%S") } }
    end

    # Hello World 首页接口
    desc "首页欢迎接口"
    get "/" do
      { code: 0, message: "Hello World! Welcome to VoiceBook API!", data: { version: "1.0.0" } }
    end

    # ==================== 挂载子模块 ====================
    mount Api::V1::Users::Mount
    mount Api::V1::Books::Mount
    mount Api::V1::Audio::Mount
    mount Api::V1::Categories::Mount
    mount Api::V1::Home::Mount
    mount Api::V1::Bookshelves::Mount
    mount Api::V1::Search::Mount
    mount Api::V1::Memberships::Mount
    mount Api::V1::Parental::Mount
    mount Api::V1::Rankings::Mount
  end
end
