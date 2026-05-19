# frozen_string_literal: true

module Entities
  class AppUser < Grape::Entity
    expose :id
    expose :phone
    expose :nickname
    expose :avatar do |instance, _|
      Book.sign_oss_url(instance.avatar)
    end
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
    expose :has_password do |instance, _|
      instance.password_digest.present?
    end
    expose :head_img do |instance, _|
      instance.head_img ? Entities::HeadImg.represent(instance.head_img).as_json : nil
    end
  end
end
