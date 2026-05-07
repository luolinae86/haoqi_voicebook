# frozen_string_literal: true

# Audio 模块辅助方法
module Api
  module Audio
    module AudioHelpers
      extend Grape::API::Helpers

      # 筛选有声专辑
      def filter_audio_albums(filters)
        books = Book.published_books.by_type(:audio)
        books = books.by_category(filters[:category_id]) if filters[:category_id].present?
        books = books.by_grade(filters[:grade_id]) if filters[:grade_id].present?
        books
      end
    end
  end
end
