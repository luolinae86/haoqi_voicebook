# frozen_string_literal: true

# 图书搜索接口
module Api
  module Books
    class SearchApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::SearchHelpers
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

          if params[:keyword].blank?
            present response: success_response(books: [], total_count: 0)
            return
          end

          books = search_books(keyword: params[:keyword], content_type: params[:content_type])

          present response: success_response(
            books: serialize_collection(books, Entities::SearchBookEntity),
            total_count: books.count("DISTINCT books.id")
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
