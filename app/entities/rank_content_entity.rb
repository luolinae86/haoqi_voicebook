# frozen_string_literal: true

module Entities
  class RankContent < Grape::Entity
    expose :id
    expose :content_type
    expose :content_type_name
    expose :sn
    expose :book do |instance, _|
      next nil unless instance.book
      {
        id: instance.book.id,
        name: instance.book.name,
        cover_url: Book.sign_oss_url(instance.book.cover_image_url),
        page_count: instance.book.page_count,
        word_count: instance.book.word_count,
        rating: instance.book.rating,
        content_description: instance.book.content_description,
        supplier_name: instance.book.supplier&.name,
        category_subs: instance.book.category_subs.map { |cs| { id: cs.id, name: cs.name, sn: cs.sn } }
      }
    end
    expose :compilation do |instance, _|
      next nil unless instance.compilation
      {
        id: instance.compilation.id,
        name: instance.compilation.name,
        cover_url: signed_oss_url(instance.compilation.banner_image_url),
        total_count: instance.compilation.total_count
      }
    end

    private

    def signed_oss_url(url)
      return nil if url.blank?
      Book.sign_oss_url(url)
    end
  end
end
