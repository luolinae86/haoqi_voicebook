# frozen_string_literal: true

module Entities
  class MinBook < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url
  end
end
