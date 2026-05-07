# frozen_string_literal: true

# 有声书接口
# 提供有声专辑列表、详情、节目播放等功能
module Api
  module V1
    module Audio
      class AudioApi < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :audio do
          # ==================== 有声专辑列表 ====================
          desc "获取有声专辑列表"
          params do
            optional :category_id, type: Integer, desc: "分类ID"
            optional :grade_id, type: Integer, desc: "年级ID"
            optional :page, type: Integer, desc: "页码", default: 1
            optional :per_page, type: Integer, desc: "每页数量", default: 10
          end
          get :albums do
            books = Book.published_books.by_type(:audio)
            books = books.by_category(params[:category_id]) if params[:category_id].present?
            books = books.by_grade(params[:grade_id]) if params[:grade_id].present?

            paged = books.page(params[:page] || 1).per(params[:per_page] || 10)
            present response: success_response, data: paged, pagination: {
              current_page: paged.current_page,
              total_pages: paged.total_pages,
              total_count: paged.total_count,
              per_page: (params[:per_page] || 10).to_i
            }
          end

          # ==================== 专辑详情 ====================
          desc "获取有声专辑详情"
          params do
            requires :id, type: Integer, desc: "图书ID"
          end
          get "albums/:id" do
            book = Book.published_books.find(params[:id])
            album = book.audio_album

            error!(err_response(code: 1003, message: "该图书没有有声内容"), 404) unless album

            present response: success_response, album: (present book, with: Entities::AlbumDetail)
          end

          # ==================== 节目列表 ====================
          desc "获取专辑节目列表"
          params do
            requires :id, type: Integer, desc: "图书ID"
            optional :page, type: Integer, desc: "页码", default: 1
            optional :per_page, type: Integer, desc: "每页数量", default: 20
          end
          get "albums/:id/episodes" do
            book = Book.find(params[:id])
            album = book.audio_album
            error!(err_response(code: 1003, message: "专辑不存在"), 404) unless album

            episodes = album.audio_episodes.ordered
            paged = episodes.page(params[:page] || 1).per(params[:per_page] || 10)

            present response: success_response, data: paged, pagination: {
              current_page: paged.current_page,
              total_pages: paged.total_pages,
              total_count: paged.total_count,
              per_page: (params[:per_page] || 10).to_i
            }
          end

          # ==================== 获取播放地址 ====================
          desc "获取节目播放地址（需要登录）"
          params do
            requires :episode_id, type: Integer, desc: "节目ID"
          end
          get "episodes/:episode_id/play" do
            episode = AudioEpisode.find(params[:episode_id])

            # 增加播放次数
            episode.increment!(:play_count)

            present response: success_response, episode: (present episode, with: Entities::AudioEpisode)
          end
        end
      end
    end
  end
end
