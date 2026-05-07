# frozen_string_literal: true

# 用户认证接口
# 提供手机号+验证码登录、密码登录、注册、找回密码等功能
module Api
  module V1
    module AppUsers
      class Auth < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :app_users do
          # ==================== 发送验证码 ====================
          desc "发送短信验证码"
          params do
            optional :uuid, type: String, desc: "用户UUID（登录时可选）"
            requires :phone, type: String, desc: "手机号"
          end
          post :send_code do
            # 仅在提供 uuid 时验证用户身份（用于已登录用户绑定手机号）
            auth_user if params[:uuid].present?

            phone = params[:phone]

            # 验证手机号格式
            error_pop_resp("手机号格式不正确") unless phone.match?(/\A1[3-9]\d{9}\z/)

            # 防止 60 秒内重复发送
            recent = SmsVerification.where(phone: phone)
                                    .where("created_at > ?", 60.seconds.ago)
                                    .exists?
            if recent
              error_pop_resp("验证码已发送，请 60 秒后再试")
            end

            # 生成4位随机验证码
            code = format("%04d", rand(10000))
            expires_at = 5.minutes.from_now

            # 创建验证码记录
            SmsVerification.create!(
              phone: phone,
              code: code,
              expires_at: expires_at
            )

            # 通过阿里云发送短信验证码
            sms_sent = AliyunSmsService.new.send_verification_code(phone, code)
            unless sms_sent
              error_pop_resp("验证码发送失败，请稍后重试")
            end

            success_response({ expires_in: 300 }, message: "验证码已发送")
          end

          # ==================== 验证码登录 ====================
          desc "手机号+验证码登录/注册"
          params do
            requires :phone, type: String, desc: "手机号"
            requires :code, type: String, desc: "验证码"
          end
          post :login_by_code do
            phone = params[:phone]
            code = params[:code]

            # 查找有效的验证码
            verification = SmsVerification.valid_codes
                                          .where(phone: phone, code: code)
                                          .order(created_at: :desc)
                                          .first

            if verification.nil?
              error_pop_resp("验证码无效或已过期")
            end

            # 标记验证码为已使用
            verification.mark_verified!

            # 查找或创建用户
            user = AppUser.find_or_create_by!(phone: phone) do |u|
              u.nickname = "用户#{phone[-4..]}"
            end

            success_response({
              user: {
                id: user.id,
                phone: user.phone,
                nickname: user.nickname,
                avatar: user.avatar,
                grade: user.grade&.name,
                is_vip: user.vip_active?,
                reading_words: user.reading_words,
                reading_minutes: user.reading_minutes,
                books_read: user.books_read,
                uuid: user.uuid,
              },
            }, message: "登录成功")
          end

          # ==================== 密码登录 ====================
          desc "手机号+密码登录"
          params do
            requires :phone, type: String, desc: "手机号"
            requires :password, type: String, desc: "密码"
          end
          post :login_by_password do
            user = AppUser.find_by(phone: params[:phone])

            if user.nil? || !user.authenticate(params[:password])
              error_pop_resp("手机号或密码错误")
            end

            success_response({
              user: {
                id: user.id,
                phone: user.phone,
                nickname: user.nickname,
                avatar: user.avatar,
                grade: user.grade&.name,
                is_vip: user.vip_active?,
                reading_words: user.reading_words,
                reading_minutes: user.reading_minutes,
                books_read: user.books_read,
                uuid: user.uuid,
              },
            }, message: "登录成功")
          end

          # ==================== 设置/重置密码 ====================
          desc "设置或重置密码"
          params do
            requires :phone, type: String, desc: "手机号"
            requires :code, type: String, desc: "验证码"
            requires :password, type: String, desc: "新密码"
          end
          post :reset_password do
            verification = SmsVerification.valid_codes
                                          .where(phone: params[:phone], code: params[:code])
                                          .order(created_at: :desc)
                                          .first

            if verification.nil?
              error_pop_resp("验证码无效或已过期")
            end

            verification.mark_verified!

            user = AppUser.find_by!(phone: params[:phone])
            user.update!(password: params[:password])

            success_response(nil, message: "密码设置成功")
          end
        end
      end
    end
  end
end
