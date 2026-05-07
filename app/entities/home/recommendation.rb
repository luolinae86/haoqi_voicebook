# frozen_string_literal: true

module Entities
  class Recommendation < Grape::Entity
    expose :id
    expose :title
    expose :description
    expose :recommendation_type, as: :type

    expose :books do |instance, options|
      limit = options[:book_limit] || 10
      instance.books.published_books.limit(limit).map do |book|
        {
          id: book.id,
          title: book.title,
          cover_image: book.cover_image,
          author: book.author,
          content_type: book.content_type
        }
      end
    end
  end
end
