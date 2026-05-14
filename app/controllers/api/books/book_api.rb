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
          books = Book.published_books
          books = filter_books(books, params.slice(:content_type, :category_id, :grade_id, :is_free, :sort_by))
          paged = books.page(params[:page] || 1).per(params[:per_page] || 10)
          present response: success_response(books: serialize_collection(paged, Entities::Book), pagination: pagination_info(paged))
        end

        # ==================== 合集资源 ====================
        desc "获取合集下的所有资源（需 uuid 鉴权）"
        params do
          requires :uuid, type: String, desc: "用户uuid"
          requires :compilation_id, type: Integer, desc: "合集ID"
        end
        get :compilation do
          auth_user
          compilation = Compilation.find(params[:compilation_id])
          books = compilation.books.published_books.order(created_at: :desc)
          contents = compilation.contents.includes(:book, :author).sorted

          serialized_books = serialize_collection(books, Entities::Book)
          serialized_contents = contents.map do |content|
            {
              id: content.id,
              content_type: content.content_type,
              img_url: content.display_img_url,
              sn: content.sn,
              book_id: content.book_id,
              compilation_id: content.compilation_id
            }
          end

          present response: success_response(
            compilation: { id: compilation.id, name: compilation.name },
            books: serialized_books,
            contents: serialized_contents
          )
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
