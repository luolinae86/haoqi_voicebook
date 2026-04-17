# frozen_string_literal: true

# 家长管控接口
# 提供家长密码设置、时间管理、内容黑名单等功能
module Api
  module V1
    module Parental
      class ParentalApi < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :parental do
          before { authenticate_user! }

          # ==================== 创建/设置家长密码 ====================
          desc "创建家长密码"
          params do
            requires :password, type: String, desc: "家长密码（4位数字）"
          end
          post :setup do
            if current_user.parental_control.present?
              return err_response(code: 1002, message: "已设置过家长密码")
            end

            control = current_user.create_parental_control!(
              password: params[:password]
            )

            success_response({ id: control.id }, message: "家长密码设置成功")
          end

          # ==================== 验证家长密码 ====================
          desc "验证家长密码"
          params do
            requires :password, type: String, desc: "家长密码"
          end
          post :verify do
            control = current_user.parental_control
            error!(err_response(code: 1003, message: "未设置家长管控"), 404) unless control

            if control.authenticate(params[:password])
              success_response(nil, message: "验证成功")
            else
              err_response(code: 1001, message: "密码错误")
            end
          end

          # ==================== 获取家长管控设置 ====================
          desc "获取家长管控设置"
          get :settings do
            control = current_user.parental_control
            error!(err_response(code: 1003, message: "未设置家长管控"), 404) unless control

            success_response({
              time_limit_minutes: control.time_limit_minutes,
              is_active: control.is_active,
              phone: control.phone,
              blacklisted_count: control.blacklisted_books.count
            })
          end

          # ==================== 设置时间限制 ====================
          desc "设置阅读时间限制"
          params do
            optional :time_limit_minutes, type: Integer, desc: "时间限制（分钟），不传表示无限制"
          end
          put :time_limit do
            control = current_user.parental_control
            error!(err_response(code: 1003, message: "未设置家长管控"), 404) unless control

            control.update!(time_limit_minutes: params[:time_limit_minutes])

            success_response({
              time_limit_minutes: control.time_limit_minutes
            }, message: "时间限制已更新")
          end

          # ==================== 预留家长手机号 ====================
          desc "预留家长手机号"
          params do
            requires :phone, type: String, desc: "家长手机号"
            requires :code, type: String, desc: "验证码"
          end
          put :phone do
            control = current_user.parental_control
            error!(err_response(code: 1003, message: "未设置家长管控"), 404) unless control

            # 验证短信验证码
            verification = SmsVerification.valid_codes
                                          .where(phone: params[:phone], code: params[:code])
                                          .order(created_at: :desc)
                                          .first

            if verification.nil?
              return err_response(code: 1002, message: "验证码无效或已过期")
            end

            verification.mark_verified!
            control.update!(phone: params[:phone])

            success_response(nil, message: "手机号已设置")
          end

          # ==================== 黑名单管理 ====================
          desc "获取黑名单图书列表"
          get :blacklist do
            control = current_user.parental_control
            error!(err_response(code: 1003, message: "未设置家长管控"), 404) unless control

            books = control.blacklisted_books.includes(:book)
            success_response(books.map { |bl|
              {
                id: bl.id,
                book_id: bl.book.id,
                title: bl.book.title,
                cover_image: bl.book.cover_image
              }
            })
          end

          desc "添加图书到黑名单"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
          end
          post :blacklist do
            control = current_user.parental_control
            error!(err_response(code: 1003, message: "未设置家长管控"), 404) unless control

            bl = control.blacklisted_books.find_or_create_by!(book_id: params[:book_id])
            success_response({ id: bl.id }, message: "已加入黑名单")
          end

          desc "从黑名单移除图书"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
          end
          delete "blacklist/:book_id" do
            control = current_user.parental_control
            error!(err_response(code: 1003, message: "未设置家长管控"), 404) unless control

            bl = control.blacklisted_books.find_by!(book_id: params[:book_id])
            bl.destroy!
            success_response(nil, message: "已从黑名单移除")
          end
        end
      end
    end
  end
end
