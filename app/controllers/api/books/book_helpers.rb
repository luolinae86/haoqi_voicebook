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

      # 构建图书单页响应内容
      def page_response(book, page)
        response = {
          book_id: book.id,
          page_number: page.page_number
        }
        # PDF 页面：返回图片 URL
        if page.image_url.present?
          response[:image_url] = signed_oss_url(page.image_url)
        end
        # EPUB 页面：返回 XHTML 标记和字数（URL 已转为签名链接）
        if page.xhtml_content.present?
          response[:xhtml_preview] = sign_xhtml_urls(extract_body_preview(page.xhtml_content), book)
          response[:word_count] = page.word_count
        end
        response[:navigation] = {
          prev_page: book.ebook_pages.before_page(page.page_number).maximum(:page_number),
          next_page: book.ebook_pages.after_page(page.page_number).minimum(:page_number)
        }
        response
      end

      # 替换 XHTML 中的 OSS URL 为签名 URL
      def sign_xhtml_urls(xhtml, book)
        known_urls = [book.styles_oss_url, book.nav_oss_url, book.epub_oss_url].compact.reject(&:blank?)
        known_urls.each do |url|
          signed = signed_oss_url(url)
          xhtml = xhtml.gsub(url, signed) if signed
        end
        xhtml = xhtml.gsub(%r{(https?://[^"'<>\s]+\.aliyuncs\.com/[^\s"'>]+)}) do |match|
          signed_oss_url(match) || match
        end
        xhtml
      end

      private

      def extract_body_preview(xhtml)
        match = xhtml.match(/<body[^>]*>(.*?)<\/body>/m)
        match ? match[1].to_s : nil
      end
    end
  end
end
