# frozen_string_literal: true

module Api
  module V1
    module Books
      module Entities
        class Chapter < Grape::Entity
          expose :id
          expose :title
          expose :content
          expose :sort_order
          expose :is_free
          expose :is_vip
          expose :word_count
        end
      end
    end
  end
end
