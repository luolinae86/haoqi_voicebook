# frozen_string_literal: true

# 图书搜索接口
module Api
  module Books
    class SearchApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::SearchHelpers
      helpers Api::Books::LeaderboardHelpers
      helpers Api::Oss::OssHelpers

      namespace :books do
        # ==================== 搜索图书 ====================
        desc '搜索图书（按书名或作者名，支持内容类型过滤）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :keyword, type: String, desc: '搜索关键词'
          optional :content_type, type: String, desc: '内容类型过滤', values: %w[ebook audio video picture_book]
        end
        get :search do
          auth_user

          books = search_books(keyword: params[:keyword], content_type: params[:content_type])

          present response: success_response(
            books: serialize_collection(books, Entities::SearchBookEntity),
            total_count: books.count('DISTINCT books.id')
          )
        end

        # ==================== 排行榜 ====================
        desc '获取图书排行榜（支持分类、排行类型过滤）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :category_id, type: Integer, desc: '分类ID'
          optional :ranking_type, type: String, desc: '排行类型', values: %w[hot rating new], default: 'hot'
          optional :period, type: String, desc: '统计周期（仅hot有效）', values: %w[week month], default: 'week'
          optional :limit, type: Integer, desc: '返回数量', default: 20
        end
        get :leaderboard do
          auth_user

          books = leaderboard_books(
            category_id: params[:category_id],
            ranking_type: params[:ranking_type],
            period: params[:period],
            grade_id: current_user.grade_id
          )

          present response: success_response(
            books: serialize_collection(books, Entities::LeaderboardBook, ranking_type: params[:ranking_type]),
            ranking_type: params[:ranking_type]
          )
        end

        # ==================== 热搜关键词 ====================
        desc '获取热门搜索关键词列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :hot_search do
          auth_user

          hot_keywords = HotSearch.active.ordered

          present response: success_response(
            keywords: serialize_collection(hot_keywords, Entities::HotSearchEntity)
          )
        end
      end
    end
  end
end
