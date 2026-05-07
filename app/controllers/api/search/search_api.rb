# frozen_string_literal: true

# 搜索接口
# 提供图书搜索和热门搜索功能
module Api
  module Search
    class SearchApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Search::SearchHelpers

      namespace :search do
        # ==================== 搜索图书 ====================
        desc "搜索图书"
        params do
          requires :keyword, type: String, desc: "搜索关键词"
          optional :content_type, type: String, desc: "内容类型"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 10
        end
        get do
          keyword = params[:keyword].strip

          record_hot_search(keyword)
          paginated_response(search_books(keyword, content_type: params[:content_type]))
        end

        # ==================== 热门搜索 ====================
        desc "获取热门搜索关键词"
        get :hot do
          keywords = hot_keywords.map { |hs| { id: hs.id, keyword: hs.keyword, search_count: hs.search_count } }

          success_response(keywords)
        end
      end
    end
  end
end
