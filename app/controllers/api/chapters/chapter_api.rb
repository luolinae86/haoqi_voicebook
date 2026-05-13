# frozen_string_literal: true

module Api
  module Chapters
    class ChapterApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Books::BookHelpers
      helpers Api::Chapters::ChapterHelpers
      helpers Api::Oss::OssHelpers

      namespace :chapters do
        # ==================== 导出章节 EPUB ====================
        desc "从章节的 PDF 异步生成 EPUB"
        params do
          requires :uuid, type: String, desc: "用户uuid"
          requires :chapter_id, type: Integer, desc: "章节ID"
          optional :force_image_pages, type: Boolean, desc: "是否强制整页图片模式"
        end
        post :export_epub do
          auth_user

          chapter = Chapter.find(params[:chapter_id])
          raise ArgumentError, "该章节没有 PDF 文件" unless chapter.content_file_url.present? && chapter.content_file_type == "pdf"

          ChapterEpubExportWorker.perform_async({
                                                  "chapter_id" => chapter.id,
                                                  "force_image_pages" => params[:force_image_pages] == true
                                                })

          present response: success_response(
                  chapter_id: chapter.id,
                  epub_export_status: chapter.epub_export_status,
                  msg: "EPUB 导出任务已提交，请轮询状态接口查看进度"
                )
        end

        # ==================== 查询 EPUB 状态 ====================
        desc "查询章节 EPUB 导出状态"
        params do
          requires :id, type: Integer, desc: "章节ID"
        end
        get ":id/epub_status" do
          chapter = Chapter.find(params[:id])

          present response: success_response(
                  chapter_id: chapter.id,
                  epub_export_status: chapter.epub_export_status,
                  epub_oss_url: signed_oss_url(chapter.epub_oss_url),
                  styles_oss_url: signed_oss_url(chapter.styles_oss_url),
                  nav_oss_url: signed_oss_url(chapter.nav_oss_url),
                  epub_export_error: chapter.epub_export_error
                )
        end

        # ==================== 页面 XHTML 内容 ====================
        desc "获取章节单页 XHTML 内容"
        params do
          requires :id, type: Integer, desc: "章节ID"
          requires :page_number, type: Integer, desc: "页码"
        end
        get ":id/pages/:page_number/html" do
          chapter = Chapter.find(params[:id])
          page = chapter.ebook_pages.find_by!(page_number: params[:page_number])

          if page.xhtml_content.present?
            env["api.format"] = :txt
            content_type "application/xhtml+xml; charset=utf-8"
            page.xhtml_content
          else
            error!({ code: 1, msg: "该页面尚未导出 XHTML" }, 404)
          end
        end

        # ==================== 样式表 ====================
        desc "获取章节电子书样式表"
        params do
          requires :id, type: Integer, desc: "章节ID"
        end
        get ":id/styles" do
          chapter = Chapter.find(params[:id])
          if chapter.styles_oss_url.present?
            redirect signed_oss_url(chapter.styles_oss_url)
          else
            error!({ code: 1, msg: "样式表尚未导出" }, 404)
          end
        end

        # ==================== 页面清单 ====================
        desc "获取章节电子书页面清单"
        params do
          requires :id, type: Integer, desc: "章节ID"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 50
        end
        get ":id/pages" do
          chapter = Chapter.find(params[:id])
          pages = chapter.ebook_pages.ordered.page(params[:page]).per(params[:per_page])

          present response: success_response(
                  chapter_id: chapter.id,
                  page_count: pages.count,
                  pages: serialize_collection(pages, Entities::EbookPage),
                  pagination: pagination_info(pages)
                )
        end

        # ==================== 页面内容 ====================
        desc "获取章节单页内容"
        params do
          requires :id, type: Integer, desc: "章节ID"
          requires :page_number, type: Integer, desc: "页码"
        end
        get ":id/pages/:page_number" do
          chapter = Chapter.find(params[:id])
          page = chapter.ebook_pages.find_by!(page_number: params[:page_number])

          present response: success_response(page_response_for_chapter(chapter, page))
        end
      end
    end
  end
end
