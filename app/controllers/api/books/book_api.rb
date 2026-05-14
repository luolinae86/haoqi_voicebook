# frozen_string_literal: true

# 图书接口
# 提供图书列表、详情、章节列表等功能
module Api
  module Books
    class BookApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::BookHelpers
      helpers Api::Oss::OssHelpers

      namespace :books do
        # ==================== 合集资源 ====================
        desc "获取合集下的所有资源（需 uuid 鉴权）"
        params do
          requires :uuid, type: String, desc: "用户uuid"
          requires :compilation_id, type: Integer, desc: "合集ID"
        end
        get :compilation do
          auth_user
          compilation = Compilation.find(params[:compilation_id])
          books = compilation.books.order(created_at: :desc)
          contents = compilation.contents.includes(:book, :author).sorted

          serialized_books = serialize_collection(books, Entities::Book)
          serialized_contents = contents.map do |content|
            {
              id: content.id,
              content_type: content.content_type,
              img_url: signed_oss_url(content.display_img_url),
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

          book = Book.find(params[:id])

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

          book = Book.find(params[:id])
          chapters = book.chapters.order(sn: :asc, id: :asc)

          present response: success_response(chapters: serialize_collection(chapters, Entities::Chapter))
        end
      end
    end
  end
end
