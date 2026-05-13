# frozen_string_literal: true

# 图书接口
# 提供图书列表、详情、章节内容等功能
module Api
  module Books
    class BookApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::BookHelpers

      namespace :books do
        # ==================== 页面 XHTML 内容 ====================
        desc "获取单页 XHTML 内容（EPUB 导出后可用）"
        params do
          requires :id, type: Integer, desc: "图书ID"
          requires :page_number, type: Integer, desc: "页码"
        end
        get ":id/pages/:page_number/html" do
          book = Book.published_books.find(params[:id])
          page = book.ebook_pages.find_by!(page_number: params[:page_number])

          if page.xhtml_content.present?
            env["api.format"] = :txt
            content_type "application/xhtml+xml; charset=utf-8"
            page.xhtml_content
          else
            error!({ code: 1, msg: "该页面尚未导出 XHTML" }, 404)
          end
        end

        # ==================== 样式表 ====================
        desc "获取电子书样式表（EPUB 导出后可用）"
        params do
          requires :id, type: Integer, desc: "图书ID"
        end
        get ":id/styles" do
          book = Book.published_books.find(params[:id])
          if book.styles_oss_url.present?
            redirect book.styles_oss_url
          else
            error!({ code: 1, msg: "样式表尚未导出" }, 404)
          end
        end

        # ==================== 目录 ====================
        desc "获取电子书目录结构"
        params do
          requires :id, type: Integer, desc: "图书ID"
        end
        get ":id/toc" do
          book = Book.published_books.find(params[:id])
          toc = build_toc(book)

          present response: success_response(toc: toc)
        end

        # ==================== 图书列表 ====================
        desc "获取图书列表"
        params do
          optional :content_type, type: String, desc: "内容类型：ebook/audio/video/picture_book"
          optional :category_id, type: Integer, desc: "分类ID"
          optional :grade_id, type: Integer, desc: "年级ID"
          optional :is_free, type: Boolean, desc: "是否免费"
          optional :sort_by, type: String, desc: "排序：popular/rating/recent", default: "recent"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 10
        end
        get do
          books = filter_books(Book.published_books, params.slice(:content_type, :category_id, :grade_id, :is_free, :sort_by))

          paged = books.page(params[:page] || 1).per(params[:per_page] || 10)
          present response: success_response(books: serialize_collection(paged, Entities::Book), pagination: pagination_info(paged))
        end

        # ==================== 图书详情 ====================
        desc "获取图书详情"
        params do
          requires :id, type: Integer, desc: "图书ID"
        end
        get ":id" do
          book = Book.published_books.find(params[:id])

          present response: success_response(book: Entities::Book.represent(book).as_json)
        end

        # ==================== 页面清单 ====================
        desc "获取电子书页面清单"
        params do
          requires :id, type: Integer, desc: "图书ID"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 50
        end
        get ":id/pages" do
          book = Book.published_books.find(params[:id])
          pages = book.ebook_pages.ordered.page(params[:page]).per(params[:per_page])

          present response: success_response(
                  book_id: book.id,
                  page_count: book.page_count,
                  pages: serialize_collection(pages, Entities::EbookPage),
                  pagination: pagination_info(pages)
                )
        end

        # ==================== 页面内容 ====================
        desc "获取电子书单页内容"
        params do
          requires :id, type: Integer, desc: "图书ID"
          requires :page_number, type: Integer, desc: "页码"
        end
        get ":id/pages/:page_number" do
          book = Book.published_books.find(params[:id])
          page = book.ebook_pages.find_by!(page_number: params[:page_number])

          present response: success_response(page_response(book, page))
        end
      end
    end
  end
end
