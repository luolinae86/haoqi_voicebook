# frozen_string_literal: true

module Entities
  class BookDetail < Grape::Entity
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

    expose :category do |instance, _|
      instance.category&.name
    end
    expose :grade do |instance, _|
      instance.grade&.name
    end
    expose :chapters_count do |instance, _|
      instance.chapters.count
    end
    expose :audio_album do |instance, _|
      instance.audio_album
    end
  end
end
