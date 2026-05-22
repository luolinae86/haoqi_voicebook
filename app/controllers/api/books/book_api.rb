# frozen_string_literal: true

# 图书接口
module Api
  module Books
    class BookApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::BookHelpers
      helpers Api::Oss::OssHelpers

      namespace :books do
        # ==================== 合集资源 ====================
        desc '获取合集下的所有资源（需 uuid 鉴权）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :compilation_id, type: Integer, desc: '合集ID'
        end
        get :compilation do
          auth_user
          compilation = Compilation.find(params[:compilation_id])
          books = compilation.books.includes(:author).order(created_at: :desc)
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
        desc '获取图书详情'
        params do
          requires :id, type: Integer, desc: '图书ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'by_id' do
          auth_user

          book = Book.find_by(id: params[:id])
          error_pop_resp('图书不存在') unless book

          present response: success_response(book: Entities::Book.represent(book).as_json)
        end

        # ==================== 目录 ====================
        desc '获取图书目录（需 uuid 鉴权）'
        params do
          requires :id, type: Integer, desc: '图书ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'catalogue' do
          auth_user

          book = Book.find_by(id: params[:id])
          error_pop_resp('图书不存在') unless book

          present response: success_response(
            book_id: book.id,
            catalogues: serialize_collection(book.catalogues.ordered, Entities::Catalogue)
          )
        end

        # ==================== 导入电子书（PDF/EPUB） ====================
        desc '导入电子书文件到图书（需 uuid 鉴权）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :id, type: Integer, desc: '图书ID'
        end
        post 'import' do
          auth_user

          book = Book.find_by(id: params[:id])
          error_pop_resp('图书不存在') if book.blank?

          file_url = book.content_file_url || book.file_url
          error_pop_resp('文件URL不存在') if file_url.blank?

          Ebook::ImportService.new(book: book, file_url: file_url).call

          present response: success_response(
            book_id: book.id,
            content_file_type: book.content_file_type,
            msg: '导入任务已提交，请轮询图书详情接口查看进度'
          )
        rescue Ebook::ImportService::Error => e
          error_pop_resp(e.message)
        end

        # ==================== 页面清单 ====================
        desc '获取图书页面清单'
        params do
          requires :id, type: Integer, desc: '图书ID'
          requires :uuid, type: String, desc: '用户uuid'
          optional :page, type: Integer, desc: '页码', default: 1
          optional :per_page, type: Integer, desc: '每页数量', default: 50
        end
        get 'pages' do
          auth_user

          book = Book.find_by(id: params[:id])
          error_pop_resp('图书不存在') unless book
          pages = book.ebook_pages.ordered.page(params[:page]).per(params[:per_page])

          present response: success_response(
            book_id: book.id,
            page_count: pages.count,
            pages: serialize_collection(pages, Entities::EbookPage),
            pagination: pagination_info(pages)
          )
        end

        # ==================== 单页内容 ====================
        desc '获取图书单页内容'
        params do
          requires :id, type: Integer, desc: '图书ID'
          requires :page_number, type: Integer, desc: '页码'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'page' do
          auth_user

          book = Book.find_by(id: params[:id])
          error_pop_resp('图书不存在') unless book
          page = book.ebook_pages.find_by!(page_number: params[:page_number])

          present response: success_response(page_response(book, page))
        end

        # ==================== 页面 XHTML 内容 ====================
        desc '获取图书单页 XHTML 内容'
        params do
          requires :id, type: Integer, desc: '图书ID'
          requires :page_number, type: Integer, desc: '页码'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'page_html' do
          auth_user

          book = Book.find_by(id: params[:id])
          error_pop_resp('图书不存在') unless book
          page = book.ebook_pages.find_by!(page_number: params[:page_number])

          if page.xhtml_content.present?
            xhtml = sign_xhtml_urls(page.xhtml_content, book)
            present response: success_response(
              book_id: book.id,
              page_number: page.page_number,
              xhtml_content: xhtml
            )
          else
            error!({ response: { code: 1, msg: '该页面尚未导出 XHTML', data: nil } }, 200)
          end
        end

        # ==================== 样式表 ====================
        desc '获取图书样式表'
        params do
          requires :id, type: Integer, desc: '图书ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'styles' do
          auth_user

          book = Book.find_by(id: params[:id])
          error_pop_resp('图书不存在') unless book
          if book.styles_oss_url.present?
            redirect signed_oss_url(book.styles_oss_url)
          else
            error!({ response: { code: 1, msg: '样式表尚未导出', data: nil } }, 200)
          end
        end
      end
    end
  end
end
