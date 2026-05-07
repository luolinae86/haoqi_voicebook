# frozen_string_literal: true

module Api
  module V1
    module Home
      module Entities
        class ReadingLevel < Grape::Entity
          expose :id
          expose :name
          expose :level
          expose :description
        end
      end
    end
  end
end
