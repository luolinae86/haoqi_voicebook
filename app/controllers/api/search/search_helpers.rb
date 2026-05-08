# frozen_string_literal: true

# Search 模块辅助方法
module Api
  module Search
    module SearchHelpers
      extend Grape::API::Helpers

      # 搜索图书
      def search_books(keyword, content_type: nil)
        books = Book.published_books.by_keyword(keyword)
        books = books.by_type(content_type) if content_type.present?
        books.recently_added
      end

      # 记录热门搜索
      def record_hot_search(keyword)
        HotSearch.find_by(keyword: keyword)&.increment_count!
      end

      # 热门搜索关键词
      def hot_keywords(limit: 10)
        HotSearch.ordered.limit(limit)
      end
    end
  end
end
