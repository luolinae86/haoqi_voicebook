# frozen_string_literal: true

module Entities
  class Package < Grape::Entity
    expose :id
    expose :name
    expose :price
    expose :origin_price
    expose :effective_days
    expose :is_discount
  end
end
