# frozen_string_literal: true

module Entities
  class Recommend < Grape::Entity
    expose :id
    expose :name
    expose :sn
    expose :status_text
  end
end
