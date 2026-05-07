# frozen_string_literal: true

module Api
  module V1
    module Categories
      module Entities
        class Grade < Grape::Entity
          expose :id
          expose :name
          expose :level
          expose :description
        end
      end
    end
  end
end
