# frozen_string_literal: true

# 书架接口
# 提供用户书架管理、阅读进度记录等功能
module Api
  module V1
    module Bookshelves
      class BookshelfApi < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :bookshelves do
          before { authenticate_user! }

          # ==================== 获取书架列表 ====================
          desc "获取用户书架"
          params do
            optional :page, type: Integer, desc: "页码", default: 1
            optional :per_page, type: Integer, desc: "每页数量", default: 20
          end
          get do
            shelves = current_user.bookshelves.recently_read.includes(:book)
            paginated_response(shelves)
          end

          # ==================== 添加到书架 ====================
          desc "添加图书到书架"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
          end
          post do
            book = Book.find(params[:book_id])
            shelf = current_user.bookshelves.find_or_create_by!(book: book)

            success_response({
              id: shelf.id,
              book_id: shelf.book_id,
              reading_progress: shelf.reading_progress
            }, message: "已添加到书架")
          end

          # ==================== 从书架移除 ====================
          desc "从书架移除图书"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
          end
          delete ":book_id" do
            shelf = current_user.bookshelves.find_by!(book_id: params[:book_id])
            shelf.destroy!

            success_response(nil, message: "已从书架移除")
          end

          # ==================== 更新阅读进度 ====================
          desc "更新阅读进度"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
            requires :progress, type: Float, desc: "阅读进度(0-100)"
            optional :chapter_id, type: Integer, desc: "当前章节ID"
          end
          put ":book_id/progress" do
            shelf = current_user.bookshelves.find_by!(book_id: params[:book_id])
            chapter = params[:chapter_id] ? Chapter.find(params[:chapter_id]) : nil
            shelf.update_progress!(progress: params[:progress], chapter: chapter)

            success_response({
              book_id: shelf.book_id,
              reading_progress: shelf.reading_progress,
              last_read_chapter_id: shelf.last_read_chapter_id
            }, message: "进度已更新")
          end

          # ==================== 记录阅读行为 ====================
          desc "记录阅读行为"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
            optional :chapter_id, type: Integer, desc: "章节ID"
            optional :words_read, type: Integer, desc: "阅读字数", default: 0
            optional :duration_minutes, type: Integer, desc: "阅读时长(分钟)", default: 0
          end
          post ":book_id/reading_records" do
            record = current_user.reading_records.create!(
              book_id: params[:book_id],
              chapter_id: params[:chapter_id],
              words_read: params[:words_read],
              duration_minutes: params[:duration_minutes],
              read_at: Time.current
            )

            # 更新用户阅读统计
            current_user.update_reading_stats!(
              words: params[:words_read],
              minutes: params[:duration_minutes]
            )

            success_response({ id: record.id }, message: "阅读记录已保存")
          end
        end

        # ==================== 书签管理 ====================
        namespace :bookmarks do
          before { authenticate_user! }

          desc "获取书签列表"
          get do
            bookmarks = current_user.bookmarks.recent.includes(:book, :chapter)
            success_response(bookmarks.map { |bm|
              {
                id: bm.id,
                book_id: bm.book_id,
                book_title: bm.book.title,
                chapter_id: bm.chapter_id,
                chapter_title: bm.chapter&.title,
                position: bm.position,
                created_at: bm.created_at.strftime("%Y-%m-%d %H:%M")
              }
            })
          end

          desc "添加书签"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
            optional :chapter_id, type: Integer, desc: "章节ID"
            optional :position, type: Float, desc: "位置"
          end
          post do
            bookmark = current_user.bookmarks.create!(
              book_id: params[:book_id],
              chapter_id: params[:chapter_id],
              position: params[:position]
            )
            success_response({ id: bookmark.id }, message: "书签已添加")
          end

          desc "删除书签"
          params do
            requires :id, type: Integer, desc: "书签ID"
          end
          delete ":id" do
            bookmark = current_user.bookmarks.find(params[:id])
            bookmark.destroy!
            success_response(nil, message: "书签已删除")
          end
        end
      end
    end
  end
end
