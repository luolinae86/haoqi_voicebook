# frozen_string_literal: true

require "uri"
require "net/http"

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

      # 替换 XHTML 中的 OSS URL 为签名 URL，并内联 CSS 样式
      def sign_xhtml_urls(xhtml, book)
        # 内联 CSS：将 <link href="..."> 替换为 <style> 标签
        if book.styles_oss_url.present?
          css_urls = book.styles_oss_url.is_a?(Array) ? book.styles_oss_url : [book.styles_oss_url]
          css_urls.each do |css_url|
            begin
              # 使用 signed_oss_url 生成可访问的签名 URL
              signed_url = signed_oss_url(css_url)
              # 下载 CSS 内容
              css_uri = URI.parse(signed_url)
              css_text = Net::HTTP.get(css_uri).force_encoding("UTF-8")
              # 将 <link href="..."> 替换为 <style> 内联
              xhtml = xhtml.gsub(%r{<link[^>]*href=["'][^"']*#{Regexp.escape(File.basename(css_url))}[^"']*["'][^>]*/?>}i,
                                 "<style>#{css_text}</style>")
            rescue StandardError => e
              Rails.logger.warn("[BookHelpers] Failed to inline CSS #{css_url}: #{e.class}: #{e.message}")
            end
          end
        end

        # 其余 OSS URL 替换为签名 URL
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
