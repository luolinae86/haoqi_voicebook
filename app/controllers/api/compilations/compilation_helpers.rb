# frozen_string_literal: true

module Api
  module Compilations
    module CompilationHelpers
      extend Grape::API::Helpers
      include Api::Oss::OssHelpers

      def compilation_detail(compilation)
        {
          id: compilation.id,
          name: compilation.name,
          description: compilation.description,
          editor_recommendation: compilation.editor_recommendation,
          total_count: compilation.total_count,
          author: compilation.author,
          publisher: compilation.publisher,
          cover_url: signed_oss_url(compilation.landscape_cover_url),
          books: compilation.books.not_in_blacklist(current_user.id).map do |book|
            {
              id: book.id,
              name: book.name,
              cover_url: signed_oss_url(book.cover_image_url)
            }
          end
        }
      end
    end
  end
end
