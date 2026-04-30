# frozen_string_literal: true

# 图书接口
# 提供图书列表、详情、章节内容等功能
module Api
  module V1
    module Books
      class BookApi < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :books do
          # ==================== 导入 PDF 电子书 ====================
          desc "上传并导入 PDF 电子书"
          params do
            optional :book_id, type: Integer, desc: "已有图书ID"
            optional :title, type: String, desc: "书名"
            optional :author, type: String, desc: "作者"
            optional :publisher, type: String, desc: "出版社"
            optional :description, type: String, desc: "简介"
            optional :cover_image, type: String, desc: "封面图"
            optional :category_id, type: Integer, desc: "分类ID"
            optional :grade_id, type: Integer, desc: "年级ID"
            optional :is_free, type: Boolean, desc: "是否免费"
            optional :is_vip, type: Boolean, desc: "是否VIP"
            optional :force_image_pages, type: Boolean, desc: "是否强制按整页图片模式导入"
            requires :pdf, type: File, desc: "PDF 文件"
          end
          post :import_pdf do
            upload = params[:pdf]
            filename = upload[:filename].to_s
            raise ArgumentError, "仅支持 PDF 文件" unless filename.downcase.end_with?(".pdf")

            book = params[:book_id].present? ? Book.find(params[:book_id]) : Book.new(status: :published)
            book.assign_attributes(
              declared(params, include_missing: false).slice(
                :title, :author, :publisher, :description, :cover_image,
                :category_id, :grade_id, :is_free, :is_vip
              ).merge(content_type: :ebook)
            )
            book.title = File.basename(filename, ".pdf") if book.title.blank?
            book.save! if book.new_record? || book.changed?

            Ebook::PdfImporter.new(
              book: book,
              pdf_path: upload[:tempfile].path,
              source_filename: filename,
              force_image_pages: params[:force_image_pages] == true
            ).call

            status 200
            success_response({
              id: book.id,
              title: book.title,
              author: book.author,
              page_count: book.page_count,
              import_status: book.import_status,
              first_page_number: book.ebook_pages.minimum(:page_number) || 1
            }, message: "PDF 导入成功")
          end

          # ==================== 异步导出 EPUB ====================
          desc "从 OSS 上的 PDF 异步生成 EPUB"
          params do
            requires :book_id, type: Integer, desc: "图书ID"
            requires :pdf_oss_key, type: String, desc: "PDF 文件在 OSS 上的路径"
            optional :force_image_pages, type: Boolean, desc: "是否强制整页图片模式"
          end
          post :export_epub do
            book = Book.find(params[:book_id])

            EpubExportWorker.perform_async({
              "book_id" => book.id,
              "pdf_oss_key" => params[:pdf_oss_key],
              "force_image_pages" => params[:force_image_pages] == true
            })

            status 202
            success_response({
              book_id: book.id,
              epub_export_status: book.epub_export_status,
              message: "EPUB 导出任务已提交，请轮询图书详情接口查看进度"
            })
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
              page_count: book.page_count,
              import_status: book.import_status,
              epub_export_status: book.epub_export_status,
              epub_oss_url: book.epub_oss_url,
              source_pdf_filename: book.source_pdf_filename,
              audio_album: book.audio_album ? {
                narrator: book.audio_album.narrator,
                total_episodes: book.audio_album.total_episodes,
                total_duration: book.audio_album.formatted_duration
              } : nil
            })
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

            success_response({
              book_id: book.id,
              page_count: book.page_count,
              pages: pages.map do |page|
                {
                  page_number: page.page_number,
                  word_count: page.word_count,
                  image_count: page.image_count,
                  excerpt: page.plain_text.to_s.first(60),
                  directory: normalized_ebook_content(page)[:directory]
                }
              end,
              pagination: {
                current_page: pages.current_page,
                total_pages: pages.total_pages,
                total_count: pages.total_count,
                per_page: params[:per_page]
              }
            })
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
            content = normalized_ebook_content(page)

            success_response({
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
                prev_page: book.ebook_pages.where("page_number < ?", page.page_number).maximum(:page_number),
                next_page: book.ebook_pages.where("page_number > ?", page.page_number).minimum(:page_number)
              }
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

        helpers do
          def normalized_ebook_content(page)
            content = page.rich_content
            return content.with_indifferent_access if content.is_a?(Hash)

            image_blocks = Array(content).select { |block| block["type"] == "image" || block[:type] == "image" }
            {
              text: page.plain_text,
              lines: [],
              images: image_blocks,
              directory: nil
            }.with_indifferent_access
          end
        end
      end
    end
  end
end
