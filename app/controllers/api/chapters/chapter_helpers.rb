# frozen_string_literal: true

# Chapter 模块辅助方法
module Api
  module Chapters
    module ChapterHelpers
      extend Grape::API::Helpers

      # 构建章节单页响应内容
      def page_response_for_chapter(chapter, page)
        rich = page.rich_content || {}
        images = (rich["images"] || []).map do |img|
          img.merge("image_url" => signed_oss_url(img["image_url"]))
        end
        {
          chapter_id: chapter.id,
          page_number: page.page_number,
          page_width: page.page_width.to_f,
          page_height: page.page_height.to_f,
          text: rich["text"].presence || page.plain_text,
          word_count: page.word_count,
          image_count: page.image_count,
          lines: rich["lines"] || [],
          images: images,
          directory: rich["directory"],
          navigation: {
            prev_page: chapter.ebook_pages.before_page(page.page_number).maximum(:page_number),
            next_page: chapter.ebook_pages.after_page(page.page_number).minimum(:page_number)
          }
        }
      end

      # 替换 XHTML 中的 OSS URL 为签名 URL
      def sign_xhtml_urls(xhtml, chapter)
        # 收集所有已知 OSS 资源 URL
        known_urls = [chapter.styles_oss_url, chapter.nav_oss_url, chapter.epub_oss_url].compact.reject(&:blank?)
        # 先替换已知 URL
        known_urls.each do |url|
          signed = signed_oss_url(url)
          xhtml = xhtml.gsub(url, signed) if signed
        end
        # 再替换 XHTML 中所有其他 oss 资源 URL
        xhtml = xhtml.gsub(%r{(https?://[^"'<>\s]+\.aliyuncs\.com/[^\s"'>]+)}) do |match|
          signed_oss_url(match) || match
        end
        xhtml
      end
    end
  end
end
