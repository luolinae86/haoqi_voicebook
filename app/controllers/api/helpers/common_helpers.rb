# frozen_string_literal: true

# API 通用辅助方法
# 提供认证、响应格式化、分页等通用功能
module Api
  module Helpers
    module CommonHelpers
      extend Grape::API::Helpers

      # ==================== 响应格式化 ====================

      # 成功响应
      # @param data [Object] 响应数据
      # @param message [String] 成功消息
      def success_response(data = nil, message: "success")
        {
          code: 0,
          message: message,
          data: data
        }
      end

      # 错误响应
      # @param code [Integer] 错误代码
      # @param message [String] 错误消息
      def err_response(code: 1001, message: "error")
        {
          code: code,
          message: message,
          data: nil
        }
      end

      # 分页响应
      # @param collection [ActiveRecord::Relation] 数据集合
      # @param message [String] 成功消息
      def paginated_response(collection, message: "success")
        paged = collection.page(params[:page] || 1).per(params[:per_page] || 10)
        {
          code: 0,
          message: message,
          data: paged,
          pagination: {
            current_page: paged.current_page,
            total_pages: paged.total_pages,
            total_count: paged.total_count,
            per_page: (params[:per_page] || 10).to_i
          }
        }
      end

      # ==================== 认证相关 ====================

      # 验证 API 客户端认证（access_key_id + sign 签名）
      # @return [ApiAuth] 认证通过的 API 客户端
      def authenticate_api!
        access_key_id = headers["X-Access-Key-Id"] || params[:access_key_id]
        sign = headers["X-Sign"] || params[:sign]

        error!(err_response(code: 1001, message: "缺少认证参数"), 401) if access_key_id.blank? || sign.blank?

        api_auth = ApiAuth.find_by(access_key_id: access_key_id)
        error!(err_response(code: 1001, message: "无效的 access_key_id"), 401) unless api_auth

        # 验证签名：对请求参数按字母排序后拼接 secret 进行 SHA1 签名
        expected_sign = generate_sign(api_auth.access_key_secret)
        error!(err_response(code: 1001, message: "签名验证失败"), 401) unless sign == expected_sign

        api_auth
      end

      # 验证用户 JWT Token
      # @return [User] 当前登录用户
      def authenticate_user!
        token = headers["Authorization"]&.gsub("Bearer ", "")
        error!(err_response(code: 1001, message: "请先登录"), 401) if token.blank?

        begin
          decoded = JWT.decode(token, jwt_secret, true, algorithm: "HS256")
          @current_user = User.find(decoded[0]["user_id"])
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound
          error!(err_response(code: 1001, message: "Token 无效或已过期"), 401)
        end
      end

      # 获取当前登录用户
      def current_user
        @current_user
      end

      # 检查用户是否为 VIP
      def require_vip!
        error!(err_response(code: 1004, message: "需要开通 VIP 会员"), 403) unless current_user&.vip_active?
      end

      private

      # 生成签名
      # @param secret [String] API 密钥
      # @return [String] SHA1 签名
      def generate_sign(secret)
        # 过滤掉签名参数本身，其余参数按键排序后拼接
        sign_params = params.except(:sign, :access_key_id, :route_info).sort.map { |k, v| "#{k}=#{v}" }.join("&")
        Digest::SHA1.hexdigest("#{sign_params}&secret=#{secret}")
      end

      # JWT 密钥
      def jwt_secret
        Rails.application.credentials.secret_key_base || "voicebook_jwt_secret_key"
      end

      # 生成 JWT Token
      # @param user [User] 用户
      # @return [String] JWT Token
      def generate_jwt_token(user)
        payload = {
          user_id: user.id,
          exp: 30.days.from_now.to_i
        }
        JWT.encode(payload, jwt_secret, "HS256")
      end
    end
  end
end
