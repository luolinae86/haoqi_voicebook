# frozen_string_literal: true

module Entities
  class Membership < Grape::Entity
    expose :id
    expose :plan_type
    expose :plan_label
    expose :price
    expose :original_price
    expose :start_date
    expose :end_date
    expose :status
  end
end
