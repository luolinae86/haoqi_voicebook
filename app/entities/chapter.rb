# frozen_string_literal: true

module Entities
  class Chapter < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url do |instance, _|
      self.class.sign_oss_url(instance.cover_image_url)
    end
    expose :content_file_type
    expose :file_type_name
    expose :is_free
    expose :is_published
    expose :publish_date
    expose :duration
    expose :sn

    def self.sign_oss_url(url, expires: 3600)
      ::Book.sign_oss_url(url, expires: expires)
    end
  end
end
