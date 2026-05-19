# frozen_string_literal: true

module Entities
  class LeaderboardItem < Grape::Entity
    expose :id
    expose :rank
    expose :score
    expose :book_id
    expose :book_name do |instance, _|
      instance.book&.name
    end
    expose :cover_image_url do |instance, _|
      Book.sign_oss_url(instance.book&.cover_image_url)
    end
    expose :word_count do |instance, _|
      instance.book&.word_count
    end
    expose :rating do |instance, _|
      instance.book&.rating
    end
  end
end
