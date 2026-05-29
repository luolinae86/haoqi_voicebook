# frozen_string_literal: true

module Entities
  class Order < Grape::Entity
    expose :id
    expose :order_no
    expose :amount
    expose :payment_method
    expose :status
    expose :paid_at do |instance, _|
      instance.paid_at&.strftime('%Y-%m-%d %H:%M:%S')
    end
    expose :membership do |instance, _|
      {
        id: instance.membership&.id,
        plan_type: instance.membership&.plan_type,
        plan_label: instance.membership&.plan_label
      }
    end
  end
end
