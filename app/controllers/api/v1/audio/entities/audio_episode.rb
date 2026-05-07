# frozen_string_literal: true

module Api
  module V1
    module Audio
      module Entities
        class AudioEpisode < Grape::Entity
          expose :id
          expose :title
          expose :sort_order
          expose :is_free
          expose :is_vip
          expose :duration
          expose :formatted_duration, as: :duration do |instance, _|
            instance.formatted_duration
          end
          expose :play_count
          expose :audio_url
        end
      end
    end
  end
end
