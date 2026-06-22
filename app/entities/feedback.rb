# frozen_string_literal: true

module Entities
  class Feedback < Grape::Entity
    expose :id
    expose :type do |instance, _|
      instance.feedback_type
    end
    expose :type_name
    expose :content
    expose :images do |instance, _|
      instance.images_array
    end
    expose :status
    expose :status_name
    expose :created_at do |instance, _|
      instance.created_at&.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
