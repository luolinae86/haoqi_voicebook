# frozen_string_literal: true

# Book 搜索模块辅助方法
module Api
  module Books
    module SearchHelpers
      extend Grape::API::Helpers

      # 搜索资源：书名 LIKE 或作者名 LIKE，返回所有状态资源
      # @param keyword [String] 搜索关键词
      # @return [ActiveRecord::Relation] 搜索结果
      def search_books(keyword:)
        Book.all
            .not_in_blacklist(current_user.id)
            .left_joins(:author, :book_stats)
            .where('books.name LIKE :kw OR authors.name LIKE :kw', kw: "%#{keyword}%")
            .select('books.*', Arel.sql('COALESCE(book_stats.weekly_readers, 0) AS weekly_readers_count'))
            .order(Arel.sql('COALESCE(book_stats.weekly_readers, 0) DESC, books.play_count DESC'))
            .distinct
      end

      # 获取热搜榜单图书
      # @param category_id [Integer] 分类ID（图书/有声/漫画）
      # @param ranking_type [String] hot/rating/new/award/classic
      # @param grade_id [Integer, nil] 年级ID
      def hot_search_books(category_id:, ranking_type:, grade_id:)
        scope = Book
                .not_in_blacklist(current_user.id)
                .includes(:author, :category, :book_stats)
                .where(category_id: category_id)

        # 按用户年级过滤
        if grade_id.present? && grade_id != 0
          scope = scope.where(
            'EXISTS (SELECT 1 FROM book_grades WHERE book_grades.book_id = books.id AND book_grades.grade_id = ?)',
            grade_id
          )
        end

        case ranking_type
        when 'hot'
          scope = scope.left_joins(:book_stats)
                       .select('books.*', Arel.sql('COALESCE(book_stats.weekly_readers, 0) AS hot_score'))
                       .order(Arel.sql('hot_score DESC'))
        when 'rating'
          scope = scope.where('rating > 0').order(rating: :desc)
        when 'new'
          scope = scope.order(created_at: :desc)
        when 'award', 'classic'
          sub_name = ranking_type == 'award' ? '大奖版' : '名著榜'
          scope = scope.joins(:category_subs)
                       .where(category_subs: { name: sub_name })
                       .left_joins(:book_stats)
                       .select('books.*', Arel.sql('COALESCE(book_stats.weekly_readers, 0) AS hot_score'))
                       .order(Arel.sql('hot_score DESC'))
        end

        scope.limit(params[:limit] || 20).distinct
      end
    end
  end
end
