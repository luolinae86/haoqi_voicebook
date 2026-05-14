# frozen_string_literal: true

# Book 模块辅助方法
module Api
  module Books
    module BookHelpers
      extend Grape::API::Helpers

      # 筛选和排序图书
      def filter_books(scope, filters)
        books = scope
        books = books.by_type(filters[:content_type]) if filters[:content_type].present?
        books = books.by_category(filters[:category_id]) if filters[:category_id].present?
        books = books.by_grade(filters[:grade_id]) if filters[:grade_id].present?
        books = books.free_books if filters[:is_free] == true
        sort_books(books, filters[:sort_by])
      end

      # 排序图书
      def sort_books(books, sort_by)
        case sort_by
        when "popular" then books.popular
        when "rating" then books.highest_rated
        else books.recently_added
        end
      end
    end
  end
end
