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

        # ==================== 资源浏览上报（统一接口） ====================
        desc '用户浏览/播放资源时调用（电子书翻页、有声书播放、视频播放统一上报）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :book_id, type: Integer, desc: '图书ID'
          optional :chapter_id, type: Integer, desc: '章节ID（有声/视频时传）'
          optional :resource_type, type: String, desc: '资源类型', values: %w[ebook audio video picture_book], default: 'ebook'
          optional :duration_seconds, type: Integer, desc: '本次浏览/播放时长（秒）', default: 0
          optional :is_complete, type: Boolean, desc: '是否完读/完播', default: false
        end
        post :resource_view do
          auth_user

          book = Book.find_by(id: params[:book_id])
          error_pop_resp('图书不存在') unless book

          chapter = params[:chapter_id].present? ? Chapter.find_by(id: params[:chapter_id], book_id: book.id) : nil
          error_pop_resp('章节不存在') if params[:chapter_id].present? && chapter.blank?

          duration = params[:duration_seconds] || 0
          stat_date = Time.zone.today.to_s

          if %w[audio video].include?(params[:resource_type] || 'ebook') && chapter
            total_dur = chapter.duration || 0
            is_valid = duration >= 10

            MediaPlayEvent.create!(
              app_user: current_user,
              book: book,
              chapter: chapter,
              media_type: params[:resource_type],
              event_type: params[:is_complete] ? 'play_complete' : 'play_start',
              play_seconds: duration,
              total_duration: total_dur,
              is_valid_play: is_valid,
              stat_date: stat_date
            )

            if params[:is_complete] && total_dur > 0 && (duration.to_f / total_dur) >= 0.8
              progress = ReadingProgress.find_or_initialize_by(app_user_id: current_user.id, book_id: book.id)
              unless progress.completed
                progress.completed = true
                progress.completed_at = Time.current
                progress.last_read_at ||= Time.current
                progress.save!
              end
            end
          else
            click_type = duration >= 30 ? 'read' : 'click'
            ContentClickEvent.create!(
              app_user: current_user,
              book: book,
              chapter: chapter,
              content_type: 'book',
              click_type: click_type,
              duration_seconds: duration,
              stat_date: stat_date
            )
          end

          present response: success_response(msg: '已记录')
        end
      end
    end
  end
end
