# frozen_string_literal: true

module Entities
  class Ranking < Grape::Entity
    expose :id
    expose :name
    expose :ranking_type
    expose :description
  end
end
