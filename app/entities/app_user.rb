# frozen_string_literal: true

module Entities
  class AppUser < Grape::Entity
    expose :id
    expose :phone
    expose :nickname
    expose :avatar do |instance, _|
      instance.head_img ? Book.sign_oss_url(instance.head_img.img_url) : nil
    end
    expose :device_id do |instance, _|
      instance.devices.order(:created_at).last&.device_id || instance.device_id
    end
    expose :uuid
    expose :grade_name do |instance, _|
      instance.grade_id ? ::Grade.find_by(id: instance.grade_id)&.name : nil
    end
    expose :reading_words
    expose :reading_minutes
    expose :books_read

    expose :is_vip do |instance, _|
      instance.is_vip?
    end
    expose :has_password do |instance, _|
      instance.password_digest.present?
    end
  end
end
