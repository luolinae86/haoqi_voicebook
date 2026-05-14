# frozen_string_literal: true

# 图书接口
# 提供图书列表、详情、章节列表等功能
module Api
  module Books
    class BookApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::BookHelpers

      namespace :books do
        # ==================== 图书列表 ====================
        desc "获取图书列表（按合集筛选）"
        params do
          optional :compilation_id, type: Integer, desc: "合集ID"
          optional :content_type, type: String, desc: "内容类型：ebook/audio/video/picture_book"
          optional :category_id, type: Integer, desc: "分类ID"
          optional :grade_id, type: Integer, desc: "年级ID"
          optional :is_free, type: Boolean, desc: "是否免费"
          optional :sort_by, type: String, desc: "排序：popular/rating/recent", default: "recent"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 10
        end
        get do
          books = Book.published_books

          if params[:compilation_id].present?
            compilation = Compilation.find(params[:compilation_id])
            books = books.joins("INNER JOIN compilation_books ON compilation_books.book_id = books.id")
                         .where(compilation_books: { compilation_id: compilation.id })
          end

          books = filter_books(books, params.slice(:content_type, :category_id, :grade_id, :is_free, :sort_by))

          paged = books.page(params[:page] || 1).per(params[:per_page] || 10)
          present response: success_response(books: serialize_collection(paged, Entities::Book), pagination: pagination_info(paged))
        end

        # ==================== 图书详情 ====================
        desc "获取图书详情"
        params do
          requires :id, type: Integer, desc: "图书ID"
          requires :uuid, type: String, desc: "用户uuid"
        end
        get ":id" do
          auth_user

          book = Book.published_books.find(params[:id])

          present response: success_response(book: Entities::Book.represent(book).as_json)
        end

        # ==================== 图书章节列表 ====================
        desc "获取图书所有章节"
        params do
          requires :id, type: Integer, desc: "图书ID"
          requires :uuid, type: String, desc: "用户uuid"
        end
        get ":id/chapters" do
          auth_user

          book = Book.published_books.find(params[:id])
          chapters = book.chapters.order(sn: :asc, id: :asc)

          present response: success_response(chapters: serialize_collection(chapters, Entities::Chapter))
        end
      end
    end
  end
end
