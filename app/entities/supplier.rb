# frozen_string_literal: true

module Entities
  class Supplier < Grape::Entity
    expose :id
    expose :name
    expose :created_at do |instance, _|
      instance.created_at&.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
