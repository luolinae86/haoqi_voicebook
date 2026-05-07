# frozen_string_literal: true

module Api
  module V1
    module Books
      module Entities
        class EbookPage < Grape::Entity
          expose :id
          expose :page_number
          expose :word_count
          expose :image_count
          expose :page_width
          expose :page_height
        end
      end
    end
  end
end
