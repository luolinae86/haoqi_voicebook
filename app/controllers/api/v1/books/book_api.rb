# frozen_string_literal: true

# 图书接口
# 提供图书列表、详情、章节内容等功能
module Api
  module V1
    module Books
      class BookApi < Grape::API
        helpers Api::Helpers::CommonHelpers

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

            # 按内容类型筛选
            books = books.by_type(params[:content_type]) if params[:content_type].present?
            # 按分类筛选
            books = books.by_category(params[:category_id]) if params[:category_id].present?
            # 按年级筛选
            books = books.by_grade(params[:grade_id]) if params[:grade_id].present?
            # 按是否免费筛选
            books = books.free_books if params[:is_free] == true

            # 排序
            books = case params[:sort_by]
                    when "popular" then books.popular
                    when "rating" then books.highest_rated
                    else books.recently_added
                    end

            paginated_response(books)
          end

          # ==================== 图书详情 ====================
          desc "获取图书详情"
          params do
            requires :id, type: Integer, desc: "图书ID"
          end
          get ":id" do
            book = Book.published_books.find(params[:id])

            success_response({
              id: book.id,
              title: book.title,
              author: book.author,
              publisher: book.publisher,
              cover_image: book.cover_image,
              description: book.description,
              content_type: book.content_type,
              is_free: book.is_free,
              is_vip: book.is_vip,
              category: book.category&.name,
              grade: book.grade&.name,
              play_count: book.play_count,
              word_count: book.word_count,
              rating: book.rating,
              isbn: book.isbn,
              chapters_count: book.chapters.count,
              audio_album: book.audio_album ? {
                narrator: book.audio_album.narrator,
                total_episodes: book.audio_album.total_episodes,
                total_duration: book.audio_album.formatted_duration
              } : nil
            })
          end

          # ==================== 章节列表 ====================
          desc "获取图书章节列表"
          params do
            requires :id, type: Integer, desc: "图书ID"
          end
          get ":id/chapters" do
            book = Book.find(params[:id])
            chapters = book.chapters.ordered

            success_response(chapters.map { |ch|
              {
                id: ch.id,
                title: ch.title,
                sort_order: ch.sort_order,
                is_free: ch.is_free,
                is_vip: ch.is_vip,
                word_count: ch.word_count
              }
            })
          end

          # ==================== 章节内容 ====================
          desc "获取章节内容（需要登录）"
          params do
            requires :id, type: Integer, desc: "图书ID"
            requires :chapter_id, type: Integer, desc: "章节ID"
          end
          get ":id/chapters/:chapter_id" do
            chapter = Chapter.find(params[:chapter_id])

            success_response({
              id: chapter.id,
              title: chapter.title,
              content: chapter.content,
              sort_order: chapter.sort_order,
              word_count: chapter.word_count,
              is_free: chapter.is_free,
              is_vip: chapter.is_vip
            })
          end
        end
      end
    end
  end
end
