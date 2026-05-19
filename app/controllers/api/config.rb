# frozen_string_literal: true

# API 默认配置
# 定义 API 的默认行为：JSON 格式、异常处理、请求日志等

# 提前加载自定义异常类，确保 Grape rescue_from 可以引用
require_relative "errors/common_error"

module Api
  class Config < Grape::API
    # 默认返回 JSON 格式
    format :json
    default_format :json

    # ==================== 异常处理 ====================

    # 捕获 Grape 参数验证异常
    rescue_from Grape::Exceptions::ValidationErrors do |e|
      error!({ response: { code: 1002, msg: e.message, data: nil } }, 400)
    end

    # 捕获 ActiveRecord 记录未找到异常
    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ response: { code: 1003, msg: "记录不存在: #{e.message}", data: nil } }, 404)
    end

    # 捕获 ActiveRecord 记录无效异常
    rescue_from ActiveRecord::RecordInvalid do |e|
      error!({ response: { code: 1002, msg: "数据验证失败: #{e.message}", data: nil } }, 422)
    end

    # 捕获自定义业务异常
    rescue_from Api::Errors::CommonError do |e|
      error!({ response: { code: e.code, msg: e.message, data: nil } }, 400)
    end

    # 捕获参数错误异常
    rescue_from ArgumentError do |e|
      error!({ response: { code: 1002, msg: "参数错误: #{e.message}", data: nil } }, 400)
    end

    # 捕获所有未知异常（生产环境不暴露详细错误）
    rescue_from :all do |e|
      Rails.logger.error("API Error: #{e.class} - #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")

      if Rails.env.production?
        error!({ response: { code: 1005, msg: "服务器内部错误", data: nil } }, 500)
      else
        error!({ response: { code: 1005, msg: "#{e.class}: #{e.message}", data: nil } }, 500)
      end
    end
  end
end
