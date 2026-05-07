# frozen_string_literal: true

# 搜索接口
# 提供图书搜索和热门搜索功能
module Api
  module Search
    class SearchApi < Grape::API
      helpers Api::Helpers::CommonHelpers

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
          books = Book.published_books.where(
            "title LIKE :kw OR author LIKE :kw OR description LIKE :kw",
            kw: "%#{keyword}%"
          )
          books = books.by_type(params[:content_type]) if params[:content_type].present?

          # 更新热门搜索计数
          hot = HotSearch.find_by(keyword: keyword)
          hot&.increment_count!

          paginated_response(books.recently_added)
        end

        # ==================== 热门搜索 ====================
        desc "获取热门搜索关键词"
        get :hot do
          keywords = HotSearch.ordered.limit(10)

          success_response(keywords.map { |hs|
            { id: hs.id, keyword: hs.keyword, search_count: hs.search_count }
          })
        end
      end
    end
  end
end
