# frozen_string_literal: true

# Book 模块辅助方法
module Api
  module Books
    module BookHelpers
      extend Grape::API::Helpers

      BOOK_ATTRIBUTES = %i[
        name author publisher description cover_image_url
        category_id grade_id is_free is_vip
      ].freeze

      # 从上传的文件构建或更新图书
      def build_book_from_file_params(book_id: nil, title: nil)
        book = book_id.present? ? Book.find(book_id) : Book.new(status: :published)
        book.assign_attributes(
          declared(params, include_missing: false).slice(*BOOK_ATTRIBUTES).merge(content_type: :ebook)
        )
        book.name = title if book.name.blank?
        book.save! if book.new_record? || book.changed?
        book
      end

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

      # 序列化页面内容
      def page_response(book, page)
        content = normalized_ebook_content(page)
        {
          book_id: book.id,
          page_number: page.page_number,
          page_width: page.page_width.to_f,
          page_height: page.page_height.to_f,
          text: content[:text].presence || page.plain_text,
          word_count: page.word_count,
          image_count: page.image_count,
          lines: content[:lines] || [],
          images: content[:images] || [],
          directory: content[:directory],
          navigation: {
            prev_page: book.ebook_pages.before_page(page.page_number).maximum(:page_number),
            next_page: book.ebook_pages.after_page(page.page_number).minimum(:page_number)
          }
        }
      end

      # 构建目录
      def build_toc(book)
        book.ebook_pages.pluck(:rich_content).compact.map do |rc|
          rc = rc.with_indifferent_access if rc.is_a?(Hash)
          rc["directory"]
        end.compact.uniq { |d| [d["title"], d["start_page_number"]] }
                   .map { |d| { title: d["title"], start_page_number: d["start_page_number"], level: d["level"] } }
      end

      # 标准化电子书内容
      def normalized_ebook_content(page)
        content = page.rich_content
        return content.with_indifferent_access if content.is_a?(Hash)

        image_blocks = Array(content).select { |block| block["type"] == "image" || block[:type] == "image" }
        { text: page.plain_text, lines: [], images: image_blocks, directory: nil }.with_indifferent_access
      end
    end
  end
end
