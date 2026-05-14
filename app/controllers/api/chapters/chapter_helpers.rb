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
        # 替换已知的 OSS 资源 URL
        [chapter.styles_oss_url, chapter.nav_oss_url, chapter.epub_oss_url].each do |url|
          next if url.blank?
          signed = signed_oss_url(url)
          xhtml = xhtml.gsub(url, signed) if signed
        end
        # 替换 XHTML 中所有匹配的 OSS 图片/资源 URL
        xhtml = xhtml.gsub(%r{(https?://[^"'<>\s]+\.aliyuncs\.com/[^\s"'>]+)}) do |match|
          begin
            uri = URI.parse(match)
            object_key = uri.path.sub(/\A\//, "")
            oss_service = AliyunOssService.new
            oss_service.generate_signed_url(object_key, expires: 3600)
          rescue URI::InvalidURIError, StandardError
            match
          end
        end
        xhtml
      end
    end
  end
end
