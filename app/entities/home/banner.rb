# frozen_string_literal: true

module Entities
  class Banner < Grape::Entity
    expose :id
    expose :title
    expose :image_url
    expose :link_url
    expose :link_type
  end
end
