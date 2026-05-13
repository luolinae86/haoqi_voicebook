# frozen_string_literal: true

# Chapter 模块辅助方法
module Api
  module Chapters
    module ChapterHelpers
      extend Grape::API::Helpers

      # 构建章节单页响应内容
      def page_response_for_chapter(chapter, page)
        content = normalized_ebook_content(page)
        {
          chapter_id: chapter.id,
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
            prev_page: chapter.ebook_pages.before_page(page.page_number).maximum(:page_number),
            next_page: chapter.ebook_pages.after_page(page.page_number).minimum(:page_number)
          }
        }
      end
    end
  end
end
