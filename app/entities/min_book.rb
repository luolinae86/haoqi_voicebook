# frozen_string_literal: true

module Entities
  class MinBook < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url do |instance, _|
      Book.sign_oss_url(instance.cover_image_url)
    end
  end
end
