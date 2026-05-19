# frozen_string_literal: true

module Entities
  class Leaderboard < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :ranking_type
    expose :description
    expose :sort_order
  end
end
