# frozen_string_literal: true

module Entities
  class SplashAd < Grape::Entity
    expose :id
    expose :image_url do |instance, _|
      Book.sign_oss_url(instance.image_url)
    end
    expose :link_type
    expose :book_id
    expose :category_id
  end
end
