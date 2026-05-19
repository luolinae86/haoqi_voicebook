# frozen_string_literal: true

# API 基础入口
# 挂载所有 API 模块，提供健康检查接口
module Api
  class Base < Config
    # 引入通用辅助方法
    helpers Api::Concerns::CommonHelpers

    # ==================== 健康检查 ====================

    # 健康检查接口，用于负载均衡和 Docker 健康检查
    desc "健康检查接口"
    get :up do
      { code: 0, msg: "VoiceBook API is running!", data: { status: "ok", time: Time.current.strftime("%Y-%m-%d %H:%M:%S") } }
    end

    # Hello World 首页接口
    desc "首页欢迎接口"
    get "/" do
      { code: 0, msg: "Hello World! Welcome to VoiceBook API!", data: { version: "1.0.0" } }
    end

    # ==================== 挂载子模块 ====================
    mount Api::AppUsers::Mount
    mount Api::Books::Mount
    mount Api::Compilations::Mount
    mount Api::Grades::Mount
    mount Api::Home::Mount
    mount Api::Memberships::Mount
    mount Api::Oss::Mount
    mount Api::Parental::Mount
    mount Api::Readings::Mount
    mount Api::Leaderboards::Mount

    # ==================== Swagger 文档 ====================
    add_swagger_documentation(
      base_path: "/api",
      info: {
        title: "狸狸阅读 API 文档",
        version: "1.0.0",
        description: "狸狸阅读（https://api.zheliyuedu.cn）全部接口文档，代码变更后自动更新"
      },
      openapi_version: "3.0",
      tags: [
        { name: "home", description: "首页推荐" },
        { name: "app_users", description: "用户认证与管理" },
        { name: "books", description: "图书、电子书阅读与页面" },
        { name: "memberships", description: "会员订阅管理" },
        { name: "oss", description: "OSS 临时授权" },
        { name: "parental", description: "家长管控" },
        { name: "reading", description: "阅读统计与进度" },
        { name: "leaderboards", description: "排行榜" }
      ],
      hide_documentation_path: false
    )
  end
end
