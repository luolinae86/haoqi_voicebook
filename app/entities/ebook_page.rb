# frozen_string_literal: true

module Entities
  class EbookPage < Grape::Entity
    expose :id
    expose :page_number
    expose :word_count
    expose :image_url do |instance, _|
      Book.sign_oss_url(instance.image_url)
    end
  end
end
