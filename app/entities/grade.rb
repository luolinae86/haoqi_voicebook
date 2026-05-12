# frozen_string_literal: true

module Entities
  class Grade < Grape::Entity
    expose :id
    expose :name
    expose :group_name
    expose :description
  end
end
