# frozen_string_literal: true

# 用户认证接口
# 提供 device_id 匿名创建、手机号+验证码登录、密码登录、微信登录、QQ登录、找回密码等功能
module Api
  module AppUsers
    class AppUserApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Concerns::SmsHelpers
      helpers Api::AppUsers::AppUserHelpers

      namespace :app_users do
        # ==================== 按 device_id 创建用户 ====================
        desc "按设备ID创建匿名用户（未绑定手机号前）"
        params do
          requires :device_id, type: String, desc: "设备ID"
        end
        post :create_by_device do
          device = Device.find_by(device_id: params[:device_id])
          if device
            user = device.app_user
          else
            user = AppUser.create!
            Device.bind!(params[:device_id], user)
          end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 发送验证码 ====================
        desc "发送短信验证码"
        params do
          requires :device_id, type: String, desc: "设备ID（登录时可选）"
          requires :phone, type: String, desc: "手机号"
        end
        post :send_code do
          auth_user if params[:device_id].present?

          validate_phone!(params[:phone])
          check_send_rate_limit!(params[:phone])

          create_and_send_code(params[:phone])

          present response: success_response(expires_in: 300)
        end

        # ==================== 验证码登录 ====================
        desc "手机号+验证码登录/注册（支持多设备共享同一账户）"
        params do
          requires :device_id, type: String, desc: "设备ID"
          requires :phone, type: String, desc: "手机号"
          requires :code, type: String, desc: "验证码"
        end
        post :login_by_code do
          # 验证码登录不需要预先 auth_user，因为 device_id 可能是新设备
          device = Device.find_by(device_id: params[:device_id])
          error_pop_resp("设备未注册，请先调用 create_by_device") unless device

          find_and_consume_verification(params[:phone], params[:code])

          existing_user = AppUser.find_by(phone: params[:phone])
          if existing_user
            # 手机号已绑定其他账户，将当前设备绑定到该账户
            device.update!(app_user: existing_user)
            user = existing_user
          else
            # 首次使用该手机号，绑定到当前设备用户
            device.app_user.update!(phone: params[:phone])
            user = device.app_user
          end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 密码登录 ====================
        desc "手机号+密码登录（支持多设备共享同一账户）"
        params do
          requires :device_id, type: String, desc: "设备ID"
          requires :phone, type: String, desc: "手机号"
          requires :password, type: String, desc: "密码"
        end
        post :login_by_password do
          device = Device.find_by(device_id: params[:device_id])
          error_pop_resp("设备未注册，请先调用 create_by_device") unless device

          user = AppUser.find_by(phone: params[:phone])
          error_pop_resp("手机号或密码错误") if user.nil? || !user.authenticate(params[:password])

          # 将当前设备绑定到该账户（如果尚未绑定）
          device.update!(app_user: user) if device.app_user_id != user.id

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 微信登录 ====================
        desc "微信授权登录（支持多设备共享同一账户）"
        params do
          requires :device_id, type: String, desc: "设备ID"
          requires :code, type: String, desc: "微信授权码"
        end
        post :login_by_wechat do
          device = Device.find_by(device_id: params[:device_id])
          error_pop_resp("设备未注册，请先调用 create_by_device") unless device

          openid = WechatAuthService.new.get_openid(params[:code])

          existing_user = AppUser.find_by(wechat_openid: openid)
          if existing_user
            # 该微信已绑定过，将当前设备绑定到该账户
            device.update!(app_user: existing_user)
            user = existing_user
          else
            # 首次微信登录，绑定到当前设备用户
            user = device.app_user
            user.update!(wechat_openid: openid, nickname: "微信用户#{openid[-4..]}") unless user.wechat_openid.present?
          end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== QQ登录 ====================
        desc "QQ授权登录（支持多设备共享同一账户）"
        params do
          requires :device_id, type: String, desc: "设备ID"
          requires :code, type: String, desc: "QQ授权码"
        end
        post :login_by_qq do
          device = Device.find_by(device_id: params[:device_id])
          error_pop_resp("设备未注册，请先调用 create_by_device") unless device

          openid = QqAuthService.new.get_openid_by_code(params[:code])

          existing_user = AppUser.find_by(qq_openid: openid)
          if existing_user
            device.update!(app_user: existing_user)
            user = existing_user
          else
            user = device.app_user
            user.update!(qq_openid: openid, nickname: "QQ用户#{openid[-4..]}") unless user.qq_openid.present?
          end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 更新用户资料 ====================
        desc "更新用户资料（昵称、年纪等）"
        params do
          requires :device_id, type: String, desc: "设备ID"
          optional :nickname, type: String, desc: "昵称（最长50字）"
          optional :grade_id, type: Integer, desc: "年纪（grade_id）"
        end
        put :update_profile do
          auth_user

          error_pop_resp("没有需要更新的字段") if params[:nickname].blank? && params[:grade_id].nil?

          attrs = {}
          attrs[:nickname] = params[:nickname] if params[:nickname].present?
          attrs[:grade_id] = params[:grade_id] unless params[:grade_id].nil?

          current_user.update!(attrs)
          present response: success_response(user: Entities::AppUser.represent(current_user).as_json)
        end

        # ==================== 设置/重置密码 ====================
        desc "设置或重置密码"
        params do
          requires :device_id, type: String, desc: "设备ID"
          requires :phone, type: String, desc: "手机号"
          requires :code, type: String, desc: "验证码"
          requires :password, type: String, desc: "新密码"
        end
        post :reset_password do
          device = Device.find_by(device_id: params[:device_id])
          error_pop_resp("设备未注册，请先调用 create_by_device") unless device

          find_and_consume_verification(params[:phone], params[:code])

          user = AppUser.find_by!(phone: params[:phone])
          user.update!(password: params[:password])

          # 将当前设备绑定到该账户
          device.update!(app_user: user) if device.app_user_id != user.id

          present response: success_response
        end
      end
    end
  end
end
