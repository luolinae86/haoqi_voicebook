# frozen_string_literal: true

module Entities
  class AppUser < Grape::Entity
    expose :id
    expose :phone
    expose :nickname
    expose :avatar
    expose :device_id do |instance, _|
      instance.devices.order(:created_at).last&.device_id || instance.device_id
    end
    expose :uuid
    expose :grade_id
    expose :reading_words
    expose :reading_minutes
    expose :books_read

    expose :is_vip do |instance, _|
      instance.is_vip?
    end
  end
end
