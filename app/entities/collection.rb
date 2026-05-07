# frozen_string_literal: true

module Entities
  class Collection < Grape::Entity
    expose :id
    expose :title
    expose :description
    expose :cover_image
    expose :collection_type, as: :type
  end
end
