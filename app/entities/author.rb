# frozen_string_literal: true

module Entities
  class Author < Grape::Entity
    expose :id
    expose :name
    expose :head_img
  end
end
