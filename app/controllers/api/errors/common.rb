# frozen_string_literal: true

# API 自定义异常类
# 统一处理 API 层面的业务异常
module Api
  module Errors
    # 通用业务异常基类
    class CommonError < StandardError
      attr_reader :code, :message

      def initialize(code: 1001, message: "未知错误")
        @code = code
        @message = message
        super(message)
      end
    end

    # 认证失败异常（access_key_id 或签名错误）
    class AuthenticationError < CommonError
      def initialize(message: "认证失败")
        super(code: 1001, message: message)
      end
    end

    # 参数验证异常
    class ValidationError < CommonError
      def initialize(message: "参数验证失败")
        super(code: 1002, message: message)
      end
    end

    # 记录未找到异常
    class NotFoundError < CommonError
      def initialize(message: "记录不存在")
        super(code: 1003, message: message)
      end
    end

    # 权限不足异常（如非 VIP 访问 VIP 内容）
    class ForbiddenError < CommonError
      def initialize(message: "权限不足")
        super(code: 1004, message: message)
      end
    end

    # 服务器内部异常
    class ServerError < CommonError
      def initialize(message: "服务器内部错误")
        super(code: 1005, message: message)
      end
    end
  end
end
