# frozen_string_literal: true

module Entities
  class MinBook < Grape::Entity
    expose :id
    expose :title
    expose :cover_image
    expose :author
  end
end
