# frozen_string_literal: true

module Api
  module Rankings
    module Entities
      class Ranking < Grape::Entity
        expose :id
        expose :name
        expose :ranking_type
        expose :description
      end
    end
  end
end
