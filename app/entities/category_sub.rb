# frozen_string_literal: true

module Entities
  class CategorySub < Grape::Entity
    expose :id
    expose :name
    expose :sn
  end
end
