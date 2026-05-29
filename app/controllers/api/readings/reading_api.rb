# frozen_string_literal: true

module Api
  module Readings
    class ReadingApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Readings::ReadingHelpers

      namespace :reading do
        # ==================== 上报阅读记录 ====================
        desc '上报阅读记录（更新阅读进度和统计）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :book_id, type: Integer, desc: '图书ID'
          requires :page_number, type: Integer, desc: '阅读到的页码'
          optional :word_count, type: Integer, desc: '本次阅读字数', default: 0
          optional :duration_seconds, type: Integer, desc: '本次阅读时长(秒)', default: 0
        end
        post 'track' do
          auth_user

          book = Book.find_by(id: params[:book_id])
          error_pop_resp('图书不存在') if book.blank?

          Reading::TrackService.new(
            app_user: current_user,
            book: book,
            page_number: params[:page_number],
            word_count: params[:word_count] || 0,
            duration_seconds: params[:duration_seconds] || 0
          ).call

          present response: success_response(msg: '阅读记录已更新')
        end

        # ==================== 我的阅读统计 ====================
        desc '获取我的阅读统计'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'my_stats' do
          auth_user

          stats = Reading::StatsService.user_stats(current_user)
          present response: success_response(stats: stats)
        end

        # ==================== 阅读时长图表数据 ====================
        desc '获取阅读时长图表数据（按周/月）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :period, type: String, desc: '统计周期', values: %w[week month]
        end
        get :chart do
          auth_user

          data = Reading::StatsService.chart_data(current_user, period: params[:period])
          present response: success_response(data)
        end

        # ==================== 我的阅读进度列表 ====================
        desc '获取我的阅读进度列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'my_progress' do
          auth_user

          progress_list = Reading::StatsService.user_progress(current_user)
          present response: success_response(reading_progress: progress_list)
        end

        # ==================== 某本书的阅读进度 ====================
        desc '获取某本书的阅读进度'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :book_id, type: Integer, desc: '图书ID'
        end
        get 'my_progress/:book_id' do
          auth_user

          progress = Reading::StatsService.user_book_progress(current_user, params[:book_id])
          if progress.blank?
            error_pop_resp('暂无阅读进度')
          end

          present response: success_response(reading_progress: progress)
        end
      end
    end
  end
end
