# frozen_string_literal: true

module Entities
  class Chapter < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url
    expose :content_file_type
    expose :is_free
    expose :is_published
    expose :sn
    expose :created_at
    expose :updated_at
  end
end
