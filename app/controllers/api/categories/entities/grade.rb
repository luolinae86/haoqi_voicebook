# frozen_string_literal: true

module Api
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
