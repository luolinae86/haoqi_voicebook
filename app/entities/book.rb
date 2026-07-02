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
    expose :supplier_name do |instance, _|
      instance.supplier&.name
    end
    expose :category_subs do |instance, _|
      instance.category_subs.map { |cs| { id: cs.id, name: cs.name, sn: cs.sn } }
    end
    expose :is_free
    expose :is_vip
    expose :grade_id
    expose :play_count
    expose :word_count
    expose :rating
    expose :status
    expose :page_count
    expose :media_id
    expose :epub_oss_url do |instance, _|
      self.class.sign_oss_url(instance.epub_oss_url)
    end
    expose :styles_oss_url do |instance, _|
      self.class.sign_oss_url(instance.styles_oss_url)
    end
    expose :created_at do |instance, _|
      instance.created_at&.strftime('%Y-%m-%d %H:%M:%S')
    end
    expose :updated_at do |instance, _|
      instance.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
    end
    expose :chapters do |instance, _|
      Entities::Chapter.represent(instance.chapters.order(:sn))
    end

    def self.sign_oss_url(url, expires: 3600)
      ::Book.sign_oss_url(url, expires: expires)
    end
  end
end
