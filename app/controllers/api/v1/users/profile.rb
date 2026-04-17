# frozen_string_literal: true

# 用户个人资料接口
# 提供查看/修改个人信息、设置年级等功能
module Api
  module V1
    module Users
      class Profile < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :users do
          # 以下接口需要登录
          before { authenticate_user! }

          # ==================== 获取个人信息 ====================
          desc "获取当前用户信息"
          get :profile do
            user = current_user
            success_response({
              id: user.id,
              phone: user.phone,
              nickname: user.nickname,
              avatar: user.avatar,
              grade: user.grade&.name,
              grade_id: user.grade_id,
              role: user.role,
              is_vip: user.vip_active?,
              vip_expires_at: user.vip_expires_at&.strftime("%Y-%m-%d"),
              reading_words: user.reading_words,
              reading_minutes: user.reading_minutes,
              books_read: user.books_read
            })
          end

          # ==================== 更新个人信息 ====================
          desc "更新个人信息"
          params do
            optional :nickname, type: String, desc: "昵称"
            optional :avatar, type: String, desc: "头像URL"
            optional :grade_id, type: Integer, desc: "年级ID"
          end
          put :profile do
            user = current_user
            update_params = declared(params, include_missing: false)
            user.update!(update_params)

            success_response({
              id: user.id,
              nickname: user.nickname,
              avatar: user.avatar,
              grade: user.grade&.name,
              grade_id: user.grade_id
            }, message: "更新成功")
          end

          # ==================== 获取阅读统计 ====================
          desc "获取阅读统计数据"
          get :reading_stats do
            user = current_user
            today_records = user.reading_records.today

            success_response({
              total: {
                reading_words: user.reading_words,
                reading_minutes: user.reading_minutes,
                books_read: user.books_read
              },
              today: {
                words_read: today_records.sum(:words_read),
                duration_minutes: today_records.sum(:duration_minutes),
                books_count: today_records.select(:book_id).distinct.count
              }
            })
          end
        end
      end
    end
  end
end
