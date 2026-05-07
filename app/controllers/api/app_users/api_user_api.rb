# frozen_string_literal: true

# 用户认证接口
# 提供手机号+验证码登录、密码登录、注册、找回密码等功能
module Api
  module AppUsers
    class ApiUserApi < Grape::API
      helpers Api::Helpers::CommonHelpers
      helpers Api::AppUsers::AppUserHelpers

      namespace :app_users do
        # ==================== 发送验证码 ====================
        desc "发送短信验证码"
        params do
          optional :device_id, type: String, desc: "设备ID（登录时可选）"
          requires :phone, type: String, desc: "手机号"
        end
        post :send_code do
          auth_user if params[:device_id].present?

          validate_phone!(params[:phone])
          check_send_rate_limit!(params[:phone])

          create_and_send_code(params[:phone])

          present response: success_response, expires_in: 300
        end

        # ==================== 验证码登录 ====================
        desc "手机号+验证码登录/注册"
        params do
          requires :phone, type: String, desc: "手机号"
          requires :code, type: String, desc: "验证码"
        end
        post :login_by_code do
          find_and_consume_verification(params[:phone], params[:code])
          user = find_or_register_user(params[:phone])

          present response: success_response, user: (present user, with: Entities::AppUser)
        end

        # ==================== 密码登录 ====================
        desc "手机号+密码登录"
        params do
          requires :phone, type: String, desc: "手机号"
          requires :password, type: String, desc: "密码"
        end
        post :login_by_password do
          user = AppUser.find_by(phone: params[:phone])
          error_pop_resp("手机号或密码错误") if user.nil? || !user.authenticate(params[:password])

          present response: success_response, user: (present user, with: Entities::AppUser)
        end

        # ==================== 设置/重置密码 ====================
        desc "设置或重置密码"
        params do
          requires :phone, type: String, desc: "手机号"
          requires :code, type: String, desc: "验证码"
          requires :password, type: String, desc: "新密码"
        end
        post :reset_password do
          find_and_consume_verification(params[:phone], params[:code])

          user = AppUser.find_by!(phone: params[:phone])
          user.update!(password: params[:password])

          present response: success_response
        end
      end
    end
  end
end
