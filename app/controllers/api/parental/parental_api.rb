# frozen_string_literal: true

# 家长管控接口
# 提供家长密码设置、时间管理、内容黑名单等功能
module Api
  module Parental
    class ParentalApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Concerns::SmsHelpers
      helpers Api::Parental::ParentalHelpers

      namespace :parental do
        # ==================== 设置家长密码 ====================
        desc "首次设置家长密码（4位数字）"
        params do
          requires :password, type: String, regexp: /\A\d{4}\z/, desc: "4位数字密码"
        end
        post :setup do
          auth_user

          error_pop_resp("家长管控已设置，无法重复创建") if current_user.parental_control.present?

          ParentalControl.create!(
            app_user: current_user,
            password: params[:password]
          )

          present response: success_response
        end

        # ==================== 验证家长密码 ====================
        desc "验证家长密码是否正确"
        params do
          requires :password, type: String, desc: "家长密码"
        end
        post :verify do
          auth_user

          parental = current_user.parental_control
          error_pop_resp("未设置家长管控") unless parental
          error_pop_resp("家长密码错误") unless parental.authenticate(params[:password])

          present response: success_response
        end

        # ==================== 获取设置 ====================
        desc "获取当前家长管控设置"
        get :settings do
          auth_user

          parental = current_user.parental_control
          error_pop_resp("未设置家长管控") unless parental

          present response: success_response, data: {
            time_limit_minutes: parental.time_limit_minutes,
            time_limit_label: time_limit_label(parental.time_limit_minutes),
            phone: parental.phone,
            phone_masked: mask_phone(parental.phone),
            blacklist_count: parental.blacklisted_books.count,
            is_active: parental.is_active
          }
        end

        # ==================== 设置时间限制 ====================
        desc "设置每日阅读时间限制"
        params do
          optional :time_limit_minutes, type: Integer, desc: "时间限制（分钟），nil 表示无限制"
        end
        put :time_limit do
          auth_user

          parental = current_user.parental_control
          error_pop_resp("未设置家长管控") unless parental

          value = params[:time_limit_minutes]
          error_pop_resp("时间限制必须为 30、60 或 90 分钟") if value.present? && ParentalControl::TIME_LIMITS.exclude?(value)

          parental.update!(time_limit_minutes: value.presence)

          present response: success_response, data: {
            time_limit_minutes: parental.time_limit_minutes,
            time_limit_label: time_limit_label(parental.time_limit_minutes)
          }
        end

        # ==================== 设置家长手机号 ====================
        desc "预留家长手机号（需短信验证）"
        params do
          requires :phone, type: String, desc: "家长手机号"
          requires :code, type: String, desc: "短信验证码"
        end
        put :phone do
          auth_user

          parental = current_user.parental_control
          error_pop_resp("未设置家长管控") unless parental

          validate_phone!(params[:phone])
          find_and_consume_verification(params[:phone], params[:code])

          parental.update!(phone: params[:phone])

          present response: success_response, data: {
            phone: parental.phone,
            phone_masked: mask_phone(parental.phone)
          }
        end

        # ==================== 黑名单列表 ====================
        desc "获取已加入黑名单的图书列表"
        params do
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 20
        end
        get :blacklist do
          auth_user

          parental = current_user.parental_control
          error_pop_resp("未设置家长管控") unless parental

          items = parental.blacklisted_books.includes(:book)
                          .page(params[:page]).per(params[:per_page])

          books = items.map do |item|
            {
              id: item.book.id,
              title: item.book.title,
              author: item.book.author,
              publisher: item.book.publisher,
              cover_image: item.book.cover_image,
              description: item.book.description,
              content_type: item.book.content_type
            }
          end

          present response: success_response, data: books,
                  pagination: pagination_info(items)
        end

        # ==================== 添加到黑名单 ====================
        desc "将图书加入黑名单"
        params do
          requires :book_id, type: Integer, desc: "图书ID"
        end
        post :blacklist do
          auth_user

          parental = current_user.parental_control
          error_pop_resp("未设置家长管控") unless parental

          book = Book.find(params[:book_id])

          parental.blacklisted_books.find_or_create_by!(book: book)

          present response: success_response
        end

        # ==================== 从黑名单移除 ====================
        desc "将图书从黑名单中移除"
        params do
          requires :book_id, type: Integer, desc: "图书ID"
        end
        delete "blacklist/:book_id" do
          auth_user

          parental = current_user.parental_control
          error_pop_resp("未设置家长管控") unless parental

          blacklisted = parental.blacklisted_books.find_by!(book_id: params[:book_id])
          blacklisted.destroy!

          present response: success_response
        end
      end
    end
  end
end
