# frozen_string_literal: true

module Entities
  class Category < Grape::Entity
    expose :id
    expose :name
    expose :level
    expose :sn
    expose :active
  end
end
