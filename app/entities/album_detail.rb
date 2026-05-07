# frozen_string_literal: true

module Entities
  class AlbumDetail < Grape::Entity
    expose :id
    expose :title
    expose :author
    expose :cover_image
    expose :description
    expose :narrator do |instance, _|
      instance.audio_album&.narrator
    end
    expose :total_episodes do |instance, _|
      instance.audio_album&.total_episodes
    end
    expose :total_duration do |instance, _|
      instance.audio_album&.formatted_duration
    end
    expose :play_count
    expose :is_vip
  end
end
