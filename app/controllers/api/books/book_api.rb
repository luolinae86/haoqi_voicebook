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
          books = compilation.books.includes(:author).order(created_at: :desc).not_in_blacklist(current_user.id)
          contents = compilation.contents.includes(:book, :author).sorted.reject { |c| book_blacklisted?(c.book_id) }

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
          check_book_not_blacklisted!(book.id)

          present response: success_response(book: Entities::Book.represent(book).as_json)
        end

        # ==================== 章节音频/视频URL ====================
        desc '获取章节内容文件URL（需 uuid 鉴权）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :chapter_id, type: Integer, desc: '章节ID'
        end
        get 'chapter_url' do
          auth_user

          chapter = Chapter.find_by(id: params[:chapter_id])
          error_pop_resp('章节不存在') unless chapter

          signed_url = chapter.content_file_url.present? ? Book.sign_oss_url(chapter.content_file_url, expires: 86_400) : nil

          present response: success_response(
            chapter_id: chapter.id,
            content_file_url: signed_url,
            content_file_type: chapter.content_file_type,
            duration: chapter.duration,
            ld_file_path: Book.sign_oss_url(chapter.ld_file_path, expires: 86_400),
            hd_file_path: Book.sign_oss_url(chapter.hd_file_path, expires: 86_400),
            sd_file_path: Book.sign_oss_url(chapter.sd_file_path, expires: 86_400)
          )
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
          check_book_not_blacklisted!(book.id)

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

          file_url = book.content_file_url
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
          check_book_not_blacklisted!(book.id)
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
          check_book_not_blacklisted!(book.id)
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
          check_book_not_blacklisted!(book.id)
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
          check_book_not_blacklisted!(book.id)
          if book.styles_oss_url.present?
            redirect signed_oss_url(book.styles_oss_url)
          else
            error!({ response: { code: 1, msg: '样式表尚未导出', data: nil } }, 200)
          end
        end

        # ==================== 批量获取封面 ====================
        desc '根据book_id数组批量获取图书封面图片URL'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :book_ids, desc: '图书ID数组'
        end
        get 'covers' do
          auth_user

          book_ids_raw = params[:book_ids]
          book_ids_raw = JSON.parse(book_ids_raw) if book_ids_raw.is_a?(String) && book_ids_raw.start_with?('[')
          book_ids = Array(book_ids_raw).map(&:to_i)
          error_pop_resp('book_ids不能为空') if book_ids.empty?

          books = Book.where(id: book_ids).not_in_blacklist(current_user.id)

          covers = books.map do |book|
            {
              book_id: book.id,
              name: book.name,
              cover_image_url: book.cover_image_url.present? ? signed_oss_url(book.cover_image_url) : nil,
              is_free: book.is_free
            }
          end

          present response: success_response(covers: covers)
        end
      end
    end
  end
end
