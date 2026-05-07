# frozen_string_literal: true

module Api
  module V1
    module Home
      module Entities
        class Banner < Grape::Entity
          expose :id
          expose :title
          expose :image_url
          expose :link_url
          expose :link_type
        end
      end
    end
  end
end
