# frozen_string_literal: true

# Book 搜索模块辅助方法
module Api
  module Books
    module SearchHelpers
      extend Grape::API::Helpers

      # 搜索图书：书名 LIKE 或作者名 LIKE，仅返回已发布书籍
      # @param keyword [String] 搜索关键词
      # @param content_type [String, nil] 内容类型过滤
      # @return [ActiveRecord::Relation] 搜索结果
      def search_books(keyword:, content_type: nil)
        scope = Book.published_books
          .left_joins(:author, :book_stats)
          .where("books.name LIKE :kw OR authors.name LIKE :kw", kw: "%#{keyword}%")

        scope = scope.by_type(content_type) if content_type.present?

        scope
          .select("books.*", Arel.sql("COALESCE(book_stats.weekly_readers, 0) AS weekly_readers_count"))
          .order(Arel.sql("COALESCE(book_stats.weekly_readers, 0) DESC, books.play_count DESC"))
          .distinct
      end
    end
  end
end
