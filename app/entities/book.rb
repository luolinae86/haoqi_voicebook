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
    expose :file_type do |instance, _|
      instance.content_file_type
    end
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
    expose :chapters do |instance, _|
      instance.chapters.order(:sn).map do |chapter|
        {
          id: chapter.id,
          name: chapter.name,
          cover_image_url: self.class.sign_oss_url(chapter.cover_image_url),
          content_file_url: self.class.sign_oss_url(chapter.content_file_url),
          content_file_name: chapter.content_file_name,
          content_file_type: chapter.content_file_type,
          file_type_name: chapter.file_type_name,
          file_type_icon: chapter.file_type_icon,
          file_type_color: chapter.file_type_color,
          is_free: chapter.is_free,
          is_published: chapter.is_published,
          sn: chapter.sn
        }
      end
    end

    def self.sign_oss_url(url)
      ::Book.sign_oss_url(url)
    end
  end
end
