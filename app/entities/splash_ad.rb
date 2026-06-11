# frozen_string_literal: true

module Entities
  class SplashAd < Grape::Entity
    expose :id
    expose :image_url do |instance, _|
      Book.sign_oss_url(instance.image_url)
    end
    expose :pad_image_url do |instance, _|
      instance.pad_image_url.present? ? Book.sign_oss_url(instance.pad_image_url) : nil
    end
    expose :link_type
    expose :link_type_name
    expose :book_id
    expose :compilation_id
    expose :compilation_name do |instance, _|
      instance.compilation_id.present? ? ::Compilation.find_by(id: instance.compilation_id)&.name : nil
    end
  end
end
