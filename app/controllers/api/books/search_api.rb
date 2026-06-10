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
        desc '搜索资源（按书名或作者名，搜索所有类型资源）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :keyword, type: String, desc: '搜索关键词'
        end
        get :search do
          auth_user

          books = search_books(keyword: params[:keyword])

          # 记录用户搜索关键词
          UserSearch.create!(app_user: current_user, keyword: params[:keyword])

          present response: success_response(
            books: serialize_collection(books, Entities::SearchBookEntity),
            total_count: books.count('DISTINCT books.id')
          )
        end

        # ==================== 热门搜索关键词 ====================
        desc '获取热门搜索关键词列表（按搜索次数降序）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :limit, type: Integer, desc: '返回数量', default: 10
        end
        get :hot_keywords do
          auth_user

          keywords = UserSearch.top_keywords(params[:limit] || 10)
                               .map { |r| { keyword: r.keyword } }

          present response: success_response(keywords: keywords)
        end

        # ==================== 按作者查询图书 ====================
        desc '根据作者ID查询作者所有图书（按播放量降序）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :author_id, type: Integer, desc: '作者ID'
          optional :category_id, type: Integer, desc: '分类ID'
        end
        get :by_author do
          auth_user

          books = Book
                  .not_in_blacklist(current_user.id)
                  .by_author(params[:author_id])
                  .left_joins(:book_stats)
                  .includes(:category, :supplier, :category_subs)

          books = books.where(category_id: params[:category_id]) if params[:category_id].present?

          books = books.order(
            Arel.sql('COALESCE(book_stats.monthly_readers, 0) DESC'),
            Arel.sql('books.play_count DESC')
          )

          present response: success_response(
            books: serialize_collection(books, Entities::SearchBookEntity),
            total_count: books.count
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

        # ==================== 热搜榜单 ====================
        desc '获取热搜图书榜单（支持分类和排行类型过滤）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :category_id, type: Integer, desc: '分类ID（图书/有声/漫画）'
          requires :ranking_type, type: String, desc: '排行类型', values: %w[hot rating new award classic]
          optional :limit, type: Integer, desc: '返回数量', default: 20
        end
        get :hot_search do
          auth_user

          books = hot_search_books(
            category_id: params[:category_id],
            ranking_type: params[:ranking_type],
            grade_id: current_user.grade_id
          )

          present response: success_response(
            books: serialize_collection(books, Entities::SearchBookEntity),
            ranking_type: params[:ranking_type]
          )
        end
      end
    end
  end
end
