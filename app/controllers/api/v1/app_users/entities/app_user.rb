# frozen_string_literal: true

module Api
  module V1
    module AppUsers
      module Entities
        class AppUser < Grape::Entity
          expose :id
          expose :phone
          expose :nickname
          expose :avatar
          expose :device_id
          expose :reading_words
          expose :reading_minutes
          expose :books_read

          expose :grade do |instance, _|
            instance.grade&.name
          end

          expose :is_vip do |instance, _|
            instance.vip_active?
          end
        end
      end
    end
  end
end
