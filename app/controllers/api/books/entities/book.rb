# frozen_string_literal: true

module Api
  module Books
    module Entities
      class Book < Grape::Entity
        expose :id
        expose :title
        expose :author
        expose :publisher
        expose :cover_image
        expose :description
        expose :content_type
        expose :is_free
        expose :is_vip
        expose :play_count
        expose :word_count
        expose :rating
        expose :isbn
        expose :page_count
        expose :import_status
        expose :epub_export_status
        expose :epub_oss_url
        expose :styles_oss_url
        expose :nav_oss_url
        expose :source_pdf_filename
        expose :created_at
      end
    end
  end
end
