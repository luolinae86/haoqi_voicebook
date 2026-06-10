# frozen_string_literal: true

# 家长管控接口
# 提供家长密码设置、时间管理、内容黑名单等功能
module Api
  module Parental
    class ParentalApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Concerns::SmsHelpers
      helpers Api::Parental::ParentalHelpers
      helpers Api::Oss::OssHelpers

      namespace :parental do
        before do
          auth_user
        end

        # ==================== 设置家长密码 ====================
        desc '首次设置家长密码（4位数字）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :password, type: String, regexp: /\A\d{4}\z/, desc: '4位数字密码'
          requires :phone, type: String, desc: '家长手机号'
          requires :code, type: String, desc: '短信验证码'
        end
        post :setup do
          validate_phone!(params[:phone])

          if current_user.parental_control.present?
            # 已设置过，手机号必须与系统一致才能重置密码
            error_pop_resp('手机号与系统记录不一致') unless current_user.parental_control.phone == params[:phone]
            find_and_consume_verification(params[:phone], params[:code])
            current_user.parental_control.update!(password: params[:password])
          else
            find_and_consume_verification(params[:phone], params[:code])
            ParentalControl.create!(
              app_user: current_user,
              password: params[:password],
              phone: params[:phone]
            )
          end

          present response: success_response
        end

        # ==================== 验证家长密码 ====================
        desc '验证家长密码是否正确'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :password, type: String, desc: '家长密码'
        end
        post :verify do
          parental = current_user.parental_control
          error_pop_resp('未设置家长管控') unless parental
          error_pop_resp('家长密码错误') unless parental.authenticate(params[:password])

          present response: success_response
        end

        # ==================== 获取设置 ====================
        desc '获取当前家长管控设置'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :settings do
          parental = current_user.parental_control
          error_pop_resp('未设置家长管控') unless parental

          present response: success_response(parental_control: Entities::ParentalControl.represent(parental).as_json)
        end

        # ==================== 设置时间限制 ====================
        desc '设置每日阅读时间限制'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :time_limit_minutes, type: Integer, desc: '时间限制（分钟），nil 表示无限制'
        end
        put :time_limit do
          parental = current_user.parental_control
          error_pop_resp('未设置家长管控') unless parental

          value = params[:time_limit_minutes]
          error_pop_resp('时间限制必须为30, 60, 90分钟或0（无限制）') if value.present? && ParentalControl::TIME_LIMITS.exclude?(value) && value != 0

          parental.update!(time_limit_minutes: value == 0 ? nil : value.presence)

          present response: success_response(
            time_limit_minutes: parental.time_limit_minutes,
            time_limit_label: time_limit_label(parental.time_limit_minutes)
          )
        end

        # ==================== 设置家长手机号 ====================
        desc '预留家长手机号（需短信验证）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :phone, type: String, desc: '家长手机号'
          requires :code, type: String, desc: '短信验证码'
        end
        put :phone do
          parental = current_user.parental_control
          error_pop_resp('未设置家长管控') unless parental

          validate_phone!(params[:phone])
          find_and_consume_verification(params[:phone], params[:code])

          parental.update!(phone: params[:phone])

          present response: success_response(
            phone: parental.phone,
            phone_masked: mask_phone(parental.phone)
          )
        end

        # ==================== 黑名单列表 ====================
        desc '获取已加入黑名单的图书列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :page, type: Integer, desc: '页码', default: 1
          optional :per_page, type: Integer, desc: '每页数量', default: 20
        end
        get :blacklist do
          parental = current_user.parental_control
          error_pop_resp('未设置家长管控') unless parental

          items = parental.blacklisted_books.includes(:book)
                          .page(params[:page]).per(params[:per_page])

          books = items.map do |item|
            Entities::Book.represent(item.book).as_json
          end

          present response: success_response(books: books, pagination: pagination_info(items))
        end

        # ==================== 添加到黑名单 ====================
        desc '将图书加入黑名单'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :book_id, type: Integer, desc: '图书ID'
        end
        post :blacklist do
          parental = current_user.parental_control
          error_pop_resp('未设置家长管控') unless parental

          book = Book.find(params.expect(:book_id))

          parental.blacklisted_books.find_or_create_by!(book: book)

          present response: success_response
        end

        # ==================== 从黑名单移除 ====================
        desc '将图书从黑名单中移除'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :book_id, type: Integer, desc: '图书ID'
        end
        delete 'blacklist/:book_id' do
          parental = current_user.parental_control
          error_pop_resp('未设置家长管控') unless parental

          blacklisted = parental.blacklisted_books.find_by!(book_id: params.expect(:book_id))
          blacklisted.destroy!

          present response: success_response
        end
      end
    end
  end
end
