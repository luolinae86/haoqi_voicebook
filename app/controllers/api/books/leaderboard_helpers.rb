# frozen_string_literal: true

# 排行榜辅助方法
module Api
  module Books
    module LeaderboardHelpers
      extend Grape::API::Helpers

      # 获取排行榜图书
      # @param category_id [Integer, nil] 分类ID
      # @param ranking_type [String] hot/rating/new
      # @param content_type [String, nil] 内容类型
      # @param period [String] week/month（仅hot有效）
      # @param grade_id [Integer, nil] 年级ID
      def leaderboard_books(category_id:, ranking_type:, content_type:, period:, grade_id:)
        scope = Book.published_books
          .includes(:author, :category, :book_stats)

        scope = scope.where(category_id: category_id) if category_id.present?
        scope = scope.by_type(content_type) if content_type.present?

        # 按用户年级过滤
        if grade_id.present?
          scope = scope.joins(:grades).where(grades: { id: grade_id }).distinct
        end

        case ranking_type
        when 'hot'
          order_field = period == 'month' \
            ? 'COALESCE(book_stats.monthly_readers, 0) DESC' \
            : 'COALESCE(book_stats.weekly_readers, 0) DESC'
          scope = scope.left_joins(:book_stats).order(Arel.sql(order_field))
        when 'rating'
          scope = scope.where('rating > 0').order(rating: :desc)
        when 'new'
          scope = scope.order(created_at: :desc)
        end

        scope.limit(params[:limit] || 20)
      end
    end
  end
end
