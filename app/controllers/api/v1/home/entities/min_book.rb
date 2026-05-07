# frozen_string_literal: true

module Api
  module V1
    module Home
      module Entities
        class MinBook < Grape::Entity
          expose :id
          expose :title
          expose :cover_image
          expose :author
        end
      end
    end
  end
end
