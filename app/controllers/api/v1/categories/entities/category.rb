# frozen_string_literal: true

module Api
  module V1
    module Categories
      module Entities
        class Category < Grape::Entity
          expose :id
          expose :name
          expose :icon
          expose :description
          expose :children_count do |instance, _|
            instance.children.count
          end
        end
      end
    end
  end
end
