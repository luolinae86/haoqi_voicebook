# frozen_string_literal: true

# 图书接口
# 提供图书列表、详情、章节内容等功能
module Api
  module Books
    class BookApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::BookHelpers

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

          book = build_book_from_file_params(book_id: params[:book_id], title: File.basename(filename, ".pdf"))

          Ebook::PdfImporter.new(
            book: book,
            pdf_path: upload[:tempfile].path,
            source_filename: filename,
            force_image_pages: params[:force_image_pages] == true
          ).call

          status 200
          present response: success_response(message: "PDF 导入成功"), book: (present book, with: Entities::BookDetail)
        end

        # ==================== 导入 EPUB 电子书 ====================
        desc "从 OSS 上的 EPUB 文件导入电子书"
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
          requires :epub_oss_key, type: String, desc: "EPUB 文件在 OSS 上的路径"
        end
        post :import_epub do
          epub_oss_key = params[:epub_oss_key]
          raise ArgumentError, "仅支持 EPUB 文件" unless epub_oss_key.downcase.end_with?(".epub")

          book = build_book_from_file_params(book_id: params[:book_id], title: File.basename(epub_oss_key, ".epub"))

          EpubImportWorker.perform_async({
                                           "book_id" => book.id,
                                           "epub_oss_key" => epub_oss_key
                                         })

          status 202
          present response: success_response, book_id: book.id, message: "EPUB 导入任务已提交，请轮询图书详情接口查看进度"
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
          present response: success_response, book_id: book.id, epub_export_status: book.epub_export_status, message: "EPUB 导出任务已提交，请轮询图书详情接口查看进度"
        end

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
            error!({ code: 1, message: "该页面尚未导出 XHTML" }, 404)
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
            error!({ code: 1, message: "样式表尚未导出" }, 404)
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

          present response: success_response, data: toc
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
          present response: success_response, data: paged, pagination: pagination_info(paged)
        end

        # ==================== 图书详情 ====================
        desc "获取图书详情"
        params do
          requires :id, type: Integer, desc: "图书ID"
        end
        get ":id" do
          book = Book.published_books.find(params[:id])

          present response: success_response, book: (present book, with: Entities::BookDetail)
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

          present response: success_response,
                  book_id: book.id,
                  page_count: book.page_count,
                  pages: serialize_collection(pages, Entities::EbookPage),
                  pagination: pagination_info(pages)
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

          present response: success_response, **page_response(book, page)
        end

        # ==================== 章节列表 ====================
        desc "获取图书章节列表"
        params do
          requires :id, type: Integer, desc: "图书ID"
        end
        get ":id/chapters" do
          book = Book.find(params[:id])
          chapters = book.chapters.ordered

          present response: success_response, chapters: serialize_collection(chapters, Entities::Chapter)
        end

        # ==================== 章节内容 ====================
        desc "获取章节内容（需要登录）"
        params do
          requires :id, type: Integer, desc: "图书ID"
          requires :chapter_id, type: Integer, desc: "章节ID"
        end
        get ":id/chapters/:chapter_id" do
          chapter = Chapter.find(params[:chapter_id])

          present response: success_response, chapter: (present chapter, with: Entities::Chapter)
        end
      end
    end
  end
end
