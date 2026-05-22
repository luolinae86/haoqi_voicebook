# frozen_string_literal: true

module Entities
  class BookChapter < Grape::Entity
    expose :id
    expose :chapter_number
    expose :chapter_name
    expose :start_page_number
    expose :word_count do |instance, _|
      instance.book.content_file_type == "epub" ? instance.calculated_word_count : instance.word_count
    end
    expose :is_free
  end
end
