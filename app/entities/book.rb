# frozen_string_literal: true

module Entities
  class Book < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url
    expose :themes
    expose :category_id
    expose :supplier_id
    expose :book_level_id
    expose :author_id
    # voicebook fields
    expose :content_type
    expose :is_free
    expose :is_vip
    expose :grade_id
    expose :play_count
    expose :word_count
    expose :rating
    expose :status
    expose :page_count
    expose :epub_oss_url
    expose :styles_oss_url
    expose :created_at
    expose :updated_at
  end
end
