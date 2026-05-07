# frozen_string_literal: true

module Api
  module Rankings
    module Entities
      class RankingItem < Grape::Entity
        expose :rank
        expose :score do |instance, _|
          instance.score.to_f
        end
        expose :book do |instance, _|
          book = instance.book
          {
            id: book.id,
            title: book.title,
            author: book.author,
            cover_image: book.cover_image,
            rating: book.rating.to_f,
            play_count: book.play_count
          }
        end
      end
    end
  end
end
