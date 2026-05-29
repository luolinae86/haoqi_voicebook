# frozen_string_literal: true

module Entities
  class Rank < Grape::Entity
    expose :id
    expose :name
    expose :sn
    expose :category_id
    expose :category_name do |instance, _|
      instance.category&.name
    end
  end
end
