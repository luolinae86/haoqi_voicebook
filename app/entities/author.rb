# frozen_string_literal: true

module Entities
  class Author < Grape::Entity
    expose :id
    expose :name
    expose :head_img do |instance, _|
      Book.sign_oss_url(instance.head_img)
    end
  end
end
