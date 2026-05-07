# frozen_string_literal: true

module Entities
  class CategoryDetail < Grape::Entity
    expose :id
    expose :name
    expose :icon
    expose :description

    expose :children do |instance, _|
      instance.children.ordered.map { |child|
        { id: child.id, name: child.name, icon: child.icon }
      }
    end
  end
end
