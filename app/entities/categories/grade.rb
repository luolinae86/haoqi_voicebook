# frozen_string_literal: true

module Entities
  class Grade < Grape::Entity
    expose :id
    expose :name
    expose :level
    expose :description
  end
end
