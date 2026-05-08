# frozen_string_literal: true

# Home 模块辅助方法
module Api
  module Home
    module HomeHelpers
      extend Grape::API::Helpers

      # 获取首页数据
      def home_data(grade_id: nil)
        {
          banners: active_banners(5),
          recommendations: recommendations_for(grade_id: grade_id, limit: 10, book_limit: 6)
        }
      end

      # 获取活跃轮播图
      def active_banners(limit = 5)
        Banner.active.ordered.limit(limit)
      end

      # 获取推荐列表
      def recommendations_for(grade_id: nil, limit: 10, book_limit: nil)
        recs = Recommendation.ordered
        recs = recs.for_grade(grade_id) if grade_id.present?
        recs = recs.limit(limit)
        book_limit ? serialize_collection(recs, Entities::Recommendation, book_limit: book_limit) : serialize_collection(recs, Entities::Recommendation)
      end

      # 筛选合集
      def filter_collections(grade_id: nil, type: nil)
        collections = Collection.ordered
        collections = collections.for_grade(grade_id) if grade_id.present?
        collections = collections.by_type(type) if type.present?
        collections
      end

      # 序列化合集图书
      def serialize_collection_books(books)
        books.map do |book|
          { id: book.id, title: book.title, cover_image: book.cover_image, author: book.author, content_type: book.content_type }
        end
      end
    end
  end
end
