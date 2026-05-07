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
      { code: 0, message: "VoiceBook API is running!", data: { status: "ok", time: Time.current.strftime("%Y-%m-%d %H:%M:%S") } }
    end

    # Hello World 首页接口
    desc "首页欢迎接口"
    get "/" do
      { code: 0, message: "Hello World! Welcome to VoiceBook API!", data: { version: "1.0.0" } }
    end

    # ==================== 挂载子模块 ====================
    mount Api::AppUsers::Mount
    mount Api::Books::Mount
    mount Api::Audio::Mount
    mount Api::Categories::Mount
    mount Api::Home::Mount
    mount Api::Search::Mount
    mount Api::Rankings::Mount

    # ==================== Swagger 文档 ====================
    add_swagger_documentation(
      base_path: "https://api.zheliyuedu.cn",
      info: {
        title: "狸狸阅读 API 文档",
        version: "1.0.0",
        description: "狸狸阅读（https://api.zheliyuedu.cn）全部接口文档，代码变更后自动更新"
      },
      openapi_version: "3.0",
      tags: [
        { name: "app_users", description: "用户认证与管理" },
        { name: "books", description: "图书管理与电子书阅读" },
        { name: "audio", description: "有声书播放" },
        { name: "categories", description: "分类与年级" },
        { name: "home", description: "首页推荐" },
        { name: "search", description: "搜索功能" },
        { name: "rankings", description: "排行榜" }
      ],
      hide_documentation_path: false
    )
  end
end
