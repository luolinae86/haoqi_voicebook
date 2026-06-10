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
          optional :channel, type: String, desc: '注册渠道（app_store/tablet/community/koc）'
        end
        post :create_by_device do
          device = Device.find_by(device_id: params[:device_id])
          user = if device&.app_user
                   device.app_user
                 else
                   create_new_app_user(params[:device_id], channel: params[:channel])
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

          credentials = WechatAuthService.new.get_credentials(params[:code])
          access_token = credentials[:access_token]
          openid = credentials[:openid]

          # 通过 access_token 获取微信用户信息（昵称、头像）
          # 注意：如果授权 scope 是 snsapi_base 或 token 过期，可能无法获取，此时仅登录不保存昵称
          begin
            wechat_info = WechatAuthService.new.get_userinfo(access_token, openid)
          rescue StandardError => e
            Rails.logger.warn("[WechatLogin] Failed to get userinfo: #{e.message}")
            wechat_info = { nickname: nil, headimgurl: nil, sex: nil }
          end

          # 检查该 openid 下是否已有绑定了手机号的主账户
          main_user = AppUser.where(wechat_openid: openid).where.not(phone: nil).where.not(id: user.id).first

          if main_user && user.phone.blank?
            # 当前用户无手机号且存在主账户，直接转移到主账户，同时更新主账户的微信昵称
            user.devices.update_all(app_user_id: main_user.id)
            main_user.update_column(:wechat_nickname, wechat_info[:nickname]) if wechat_info[:nickname].present?
            user.destroy
            expire_user_cache(main_user.uuid)
            user = main_user
          else
            # 正常流程：更新当前用户的 openid 和昵称
            # 如果 openid 被其他用户占用，先清空其绑定
            other_user = AppUser.find_by(wechat_openid: openid)
            other_user&.update!(wechat_openid: nil) if other_user && other_user != user

            attrs = { wechat_openid: openid }
            attrs[:wechat_nickname] = wechat_info[:nickname] if wechat_info[:nickname].present?
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
            error_pop_resp('修改密码需要提供手机号') if params[:phone].blank?
            target_user = AppUser.find_by(phone: params[:phone])
            error_pop_resp('该手机号未绑定账户') if target_user.blank?
            error_pop_resp('修改密码需要提供验证码') if params[:code].blank?
            find_and_consume_verification(params[:phone], params[:code])
            target_user.update!(password: params[:password])
          else
            # 首次设置密码，直接给当前用户设置
            user.update!(password: params[:password])
          end

          present response: success_response
        end

        # ==================== 更新推送 CID ====================
        desc '更新个推推送 CID（客户端获取到个推 CID 后调用）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :push_cid, type: String, desc: '个推客户端 CID'
        end
        post :update_push_cid do
          auth_user

          # 查找当前设备（按最新设备优先）
          device = current_user.devices.order(created_at: :desc).first
          if device
            device.update!(push_cid: params[:push_cid])
          else
            # 兼容旧用户可能没有 devices 记录
            Device.create!(app_user: current_user, device_id: current_user.device_id, push_cid: params[:push_cid])
          end

          present response: success_response(msg: '推送 CID 已更新')
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

        # ==================== 开屏广告点击统计 ====================
        desc '记录开屏广告点击（客户端点击广告后调用）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :splash_ad_id, type: Integer, desc: '开屏广告ID'
          optional :send_count, type: Integer, desc: '发送数（传入则 send_count 加 1）'
          optional :click_count, type: Integer, desc: '点击数（传入则 click_count 加 1）'
        end
        post :splash_ad_click do
          auth_user

          ad = SplashAd.find_by(id: params[:splash_ad_id])
          error_pop_resp('广告不存在') unless ad

          updates = {}
          updates[:send_count] = ad.send_count + params[:send_count] if params[:send_count].present?
          updates[:click_count] = ad.click_count + params[:click_count] if params[:click_count].present?

          ad.update!(updates) unless updates.empty?

          present response: success_response(
            send_count: ad.send_count,
            click_count: ad.click_count
          )
        end

        # ==================== 解绑微信 ====================
        desc '解绑微信授权（清除用户的 wechat_openid 和 wechat_nickname，下次微信登录需重新绑定）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        post :unbind_wechat do
          auth_user

          error_pop_resp('当前账号未绑定微信') if current_user.wechat_openid.blank?

          current_user.update!(wechat_openid: nil, wechat_nickname: nil)
          expire_user_cache(params[:uuid])

          present response: success_response(msg: '微信已解绑')
        end
      end
    end
  end
end
