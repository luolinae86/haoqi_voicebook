# frozen_string_literal: true

module Entities
  class HotSearchEntity < Grape::Entity
    expose :id
    expose :keyword
  end
end
