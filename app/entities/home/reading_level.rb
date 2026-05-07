# frozen_string_literal: true

module Entities
  class ReadingLevel < Grape::Entity
    expose :id
    expose :name
    expose :level
    expose :description
  end
end
