# frozen_string_literal: true

module Entities
  class Supplier < Grape::Entity
    expose :id
    expose :name
    expose :created_at
  end
end
