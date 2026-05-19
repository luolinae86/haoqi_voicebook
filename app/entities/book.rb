# frozen_string_literal: true

module Entities
  class Book < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url do |instance, _|
      self.class.sign_oss_url(instance.cover_image_url)
    end
    expose :themes
    expose :category_id
    expose :supplier_id
    expose :book_level_id
    expose :author_id
    expose :author_name do |instance, _|
      instance.author ? "#{instance.author.name}【著】" : nil
    end
    # voicebook fields
    expose :file_type
    expose :content_description
    expose :is_free
    expose :is_vip
    expose :grade_id
    expose :play_count
    expose :word_count
    expose :rating
    expose :status
    expose :page_count
    expose :epub_oss_url do |instance, _|
      self.class.sign_oss_url(instance.epub_oss_url)
    end
    expose :styles_oss_url do |instance, _|
      self.class.sign_oss_url(instance.styles_oss_url)
    end
    expose :created_at
    expose :updated_at

    def self.sign_oss_url(url)
      ::Book.sign_oss_url(url)
    end
  end
end
