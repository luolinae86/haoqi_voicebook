# frozen_string_literal: true

# 客户端数据上报接口
module Api
  module Report
    class ReportApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :report do
        # ==================== 打开 APP 上报 ====================
        desc '用户打开 APP 时调用（用于统计 DAU/WAU/MAU/留存率）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :channel, type: String, desc: '渠道标识（app_store/tablet/community/koc）'
        end
        post :app_open do
          user = AppUser.find_by(uuid: params[:uuid])
          error_pop_resp('用户未注册') unless user

          UserActivityLog.log_app_open(user, channel: params[:channel])

          present response: success_response(msg: '已记录')
        end

        # ==================== 内容点击上报 ====================
        desc '用户点击或阅读内容时调用（用于统计内容消费数据）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :book_id, type: Integer, desc: '图书ID'
          optional :chapter_id, type: Integer, desc: '章节ID（有声/视频专用）'
          optional :content_type, type: String, desc: '类型', values: %w[book chapter], default: 'book'
          requires :click_type, type: String, desc: '点击类型', values: %w[click read play_start]
          optional :duration_seconds, type: Integer, desc: '本次停留/播放时长（秒）', default: 0
        end
        post :content_click do
          auth_user

          book = Book.find_by(id: params[:book_id])
          error_pop_resp('图书不存在') unless book

          if params[:chapter_id].present?
            chapter = Chapter.find_by(id: params[:chapter_id], book_id: book.id)
            error_pop_resp('章节不存在') unless chapter
          end

          ContentClickEvent.create!(
            app_user: current_user,
            book: book,
            chapter: chapter,
            content_type: params[:content_type] || 'book',
            click_type: params[:click_type],
            duration_seconds: params[:duration_seconds] || 0,
            stat_date: Time.zone.today.to_s
          )

          present response: success_response(msg: '已记录')
        end

        # ==================== 有声/视频播放上报 ====================
        desc '播放音频/视频时调用（用于统计播放量、完播率）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :book_id, type: Integer, desc: '图书ID'
          requires :chapter_id, type: Integer, desc: '章节ID'
          requires :media_type, type: String, desc: '媒体类型', values: %w[audio video]
          requires :event_type, type: String, desc: '事件类型', values: %w[play_start play_resume play_pause play_complete]
          optional :play_seconds, type: Integer, desc: '本次播放时长（秒）', default: 0
          optional :total_duration, type: Integer, desc: '章节总时长（秒）', default: 0
        end
        post :media_play do
          auth_user

          book = Book.find_by(id: params[:book_id])
          error_pop_resp('图书不存在') unless book

          chapter = Chapter.find_by(id: params[:chapter_id], book_id: book.id)
          error_pop_resp('章节不存在') unless chapter

          play_seconds = params[:play_seconds] || 0
          total_duration = params[:total_duration] || chapter.duration || 0
          is_valid_play = play_seconds >= 10

          event = MediaPlayEvent.create!(
            app_user: current_user,
            book: book,
            chapter: chapter,
            media_type: params[:media_type],
            event_type: params[:event_type],
            play_seconds: play_seconds,
            total_duration: total_duration,
            is_valid_play: is_valid_play,
            stat_date: Time.zone.today.to_s
          )

          # 有声/视频完读：播放完成且播放时长 >= 80%，标记该书阅读进度为 completed
          if params[:event_type] == 'play_complete' && total_duration > 0 && (play_seconds.to_f / total_duration) >= 0.8
            progress = ReadingProgress.find_or_initialize_by(
              app_user_id: current_user.id,
              book_id: book.id
            )
            unless progress.completed
              progress.completed = true
              progress.completed_at = Time.current
              progress.last_read_at ||= Time.current
              progress.save!
            end
          end

          present response: success_response(msg: '已记录', event_id: event.id, is_valid_play: is_valid_play)
        end
      end
    end
  end
end
