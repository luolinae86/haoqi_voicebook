# frozen_string_literal: true

module Entities
  class ReadingProgress < Grape::Entity
    expose :book_id
    expose :book_name do |instance, _|
      instance.book&.name
    end
    expose :cover_image_url do |instance, _|
      Book.sign_oss_url(instance.book&.cover_image_url)
    end
    expose :last_page_number
    expose :total_pages do |instance, _|
      instance.book&.page_count
    end
    expose :total_words_read
    expose :session_count
    expose :completed
    expose :last_read_at do |instance, _|
      instance.last_read_at&.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
