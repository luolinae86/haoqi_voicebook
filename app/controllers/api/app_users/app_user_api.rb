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
        desc '按设备ID创建匿名用户（新用户注册，未绑定手机号前）'
        params do
          requires :device_id, type: String, desc: '设备ID'
        end
        post :create_by_device do
          device = Device.find_by(device_id: params[:device_id])
          user = if device&.app_user
                   device.app_user
                 else
                   create_new_app_user(params[:device_id])
                 end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 发送验证码 ====================
        desc '发送短信验证码'
        params do
          requires :uuid, type: String, desc: '用户uuid（登录时可选）'
          requires :phone, type: String, desc: '手机号'
        end
        post :send_code do
          auth_user if params[:uuid].present?

          validate_phone!(params[:phone])
          check_send_rate_limit!(params[:phone])

          create_and_send_code(params[:phone])

          present response: success_response(expires_in: 300)
        end

        # ==================== 验证码登录 ====================
        desc '手机号+验证码登录/注册（支持多设备共享同一账户）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :phone, type: String, desc: '手机号'
          requires :code, type: String, desc: '验证码'
        end
        post :login_by_code do
          user = AppUser.find_by(uuid: params[:uuid])
          error_pop_resp('用户未注册，请先调用 create_by_device') unless user

          find_and_consume_verification(params[:phone], params[:code])

          # 如果手机号已绑定其他用户，将当前设备重新绑定到主账户
          existing_user = AppUser.find_by(phone: params[:phone])
          if existing_user
            # 将当前用户的 wechat_openid 同步到主账户（先清空当前用户的 openid 避免唯一索引冲突）
            if user.wechat_openid.present?
              openid_val = user.wechat_openid
              nickname_val = user.wechat_nickname
              user.update_column(:wechat_openid, nil)
              existing_user.update_columns(wechat_openid: openid_val, wechat_nickname: nickname_val)
            end

            # 将当前用户的设备全部转移绑定到已存在的主账户
            user.devices.update_all(app_user_id: existing_user.id)
            # 删除当前用户（设备已转移，原用户不再需要）
            user.destroy
            expire_user_cache(existing_user.uuid)
            user = existing_user
          else
            user.update!(phone: params[:phone])
            expire_user_cache(params[:uuid])
          end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 密码登录 ====================
        desc '手机号+密码登录（支持多设备共享同一账户）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :phone, type: String, desc: '手机号'
          requires :password, type: String, desc: '密码'
        end
        post :login_by_password do
          user = AppUser.find_by(uuid: params[:uuid])
          error_pop_resp('用户未注册，请先调用 create_by_device') unless user

          user = AppUser.find_by(phone: params[:phone])
          error_pop_resp('手机号或密码错误') if user.nil? || !user.authenticate(params[:password])

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 微信登录 ====================
        desc '微信授权登录（支持多设备共享同一账户）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :code, type: String, desc: '微信授权码'
        end
        post :login_by_wechat do
          user = AppUser.find_by(uuid: params[:uuid])
          error_pop_resp('用户未注册，请先调用 create_by_device') unless user

          openid = WechatAuthService.new.get_openid(params[:code])

          # 检查该 openid 下是否已有绑定了手机号的主账户
          main_user = AppUser.where(wechat_openid: openid).where.not(phone: nil).where.not(id: user.id).first

          if main_user && user.phone.blank?
            # 当前用户无手机号且存在主账户，直接转移到主账户
            user.devices.update_all(app_user_id: main_user.id)
            user.destroy
            expire_user_cache(main_user.uuid)
            user = main_user
          else
            # 正常流程：更新当前用户的 openid
            # 如果 openid 被其他用户占用，先清空其绑定
            other_user = AppUser.find_by(wechat_openid: openid)
            other_user&.update!(wechat_openid: nil) if other_user && other_user != user

            attrs = { wechat_openid: openid }
            attrs[:wechat_nickname] = params[:wechat_nickname] if params[:wechat_nickname].present?
            user.update!(attrs)
            expire_user_cache(params[:uuid])

            # 更新后仍无手机号，提示绑定
            error_pop_resp('请绑定手机号') if user.phone.blank?
          end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        rescue StandardError
          # 微信授权码已被使用或其他异常，返回友好提示
          error_pop_resp('授权已过期，请重新授权登录')
        end

        # ==================== QQ登录 ====================
        desc 'QQ授权登录（支持多设备共享同一账户）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :code, type: String, desc: 'QQ授权码'
        end
        post :login_by_qq do
          user = AppUser.find_by(uuid: params[:uuid])
          error_pop_resp('用户未注册，请先调用 create_by_device') unless user

          openid = QqAuthService.new.get_openid_by_code(params[:code])

          existing_user = AppUser.find_by(qq_openid: openid)
          if existing_user
            user = existing_user
          else
            user.update!(qq_openid: openid, nickname: "QQ用户#{openid[-4..]}") unless user.qq_openid.present?
            expire_user_cache(params[:uuid])
          end

          present response: success_response(user: Entities::AppUser.represent(user).as_json)
        end

        # ==================== 用户配置 ====================
        desc '获取用户配置（App启动时调用，高频接口）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :config do
          auth_user

          # 高频接口，使用缓存避免重复查询 parental_controls 表
          time_limit_minutes = Rails.cache.fetch(
            "parental_time_limit_#{current_user.id}",
            expires_in: 5.minutes,
            version: current_user.parental_control&.updated_at.to_i
          ) do
            current_user.parental_control&.time_limit_minutes || 0
          end

          present response: success_response(
            time_limit_minutes: time_limit_minutes
          )
        end

        # ==================== 获取用户信息 ====================
        desc '获取当前设备绑定的用户基本信息'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :info do
          auth_user

          present response: success_response(user: Entities::AppUser.represent(current_user).as_json)
        end

        # ==================== 更新用户资料 ====================
        desc '更新用户资料（昵称、年纪、头像）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :nickname, type: String, desc: '昵称（最长50字）'
          optional :grade_id, type: Integer, desc: '年纪（grade_id）'
          optional :head_img_id, type: Integer, desc: '头像ID（从头像列表中选择）'
        end
        put :update_profile do
          auth_user

          error_pop_resp('没有需要更新的字段') if params[:nickname].blank? && params[:grade_id].nil? && params[:head_img_id].nil?

          attrs = {}
          attrs[:nickname] = params[:nickname] if params[:nickname].present?
          attrs[:grade_id] = params[:grade_id] unless params[:grade_id].nil?

          if params[:head_img_id].present?
            head_img = HeadImg.find_by(id: params[:head_img_id])
            # 非VIP用户不能选择VIP头像
            error_pop_resp('VIP头像需要VIP会员才能使用') if head_img&.is_vip? && !current_user.is_vip?
            error_pop_resp('头像不存在') unless head_img
            attrs[:head_img_id] = head_img.id
          end

          current_user.update!(attrs)
          expire_user_cache(params[:uuid])
          present response: success_response(user: Entities::AppUser.represent(current_user).as_json)
        end

        # ==================== 设置/重置密码 ====================
        desc '设置或重置密码（首次设置无需验证码，修改密码需手机号+验证码）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :password, type: String, desc: '新密码'
          optional :phone, type: String, desc: '手机号（修改已有密码时必须）'
          optional :code, type: String, desc: '验证码（修改已有密码时必须）'
        end
        post :reset_password do
          user = AppUser.find_by(uuid: params[:uuid])
          error_pop_resp('用户未注册，请先调用 create_by_device') if user.blank?

          if user.password_digest.present?
            # 已有密码，修改时必须验证手机号和验证码
            error_pop_resp('修改密码需要提供手机号和验证码') if params[:phone].blank? || params[:code].blank?
            find_and_consume_verification(params[:phone], params[:code])
          end

          error_pop_resp('修改密码需要提供手机号') if params[:phone].blank?
          target_user = AppUser.find_by(phone: params[:phone])
          error_pop_resp('该手机号未绑定账户') if target_user.blank?

          target_user.update!(password: params[:password])

          present response: success_response
        end

        # ==================== 注销账户 ====================
        desc '注销账户（删除用户及其所有资源，解绑所有设备并创建新匿名账户）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        post :delete_account do
          auth_user

          # 记录当前请求的设备ID，用于返回新账户
          current_device_id = current_user.devices.order(:created_at).last&.device_id || current_user.device_id

          device_ids = current_user.devices.pluck(:device_id)
          current_user.destroy

          new_user = nil
          device_ids.each do |device_id|
            user = create_new_app_user(device_id)
            new_user = user if device_id == current_device_id
          end

          present response: success_response(
            msg: '账户已注销',
            user: new_user ? Entities::AppUser.represent(new_user).as_json : nil
          )
        end

        # ==================== 退出登录 ====================
        desc '退出登录（解绑当前设备，返回新用户）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        post :logout do
          auth_user

          device = current_user.devices.first
          if device
            Device.unbind!(device.device_id)
            expire_user_cache(current_user.uuid)
          end

          new_user = create_new_app_user(device&.device_id)
          present response: success_response(user: Entities::AppUser.represent(new_user).as_json)
        end
      end
    end
  end
end
