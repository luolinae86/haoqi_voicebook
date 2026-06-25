# frozen_string_literal: true

module Entities
  class SearchBookEntity < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url do |instance, _|
      Book.sign_oss_url(instance.cover_image_url)
    end
    expose :content_type
    expose :author_name do |instance, _|
      instance.author ? instance.author.name : nil
    end
    expose :category_id
    expose :category_name do |instance, _|
      instance.category ? instance.category.name : nil
    end
    expose :content_description
    expose :supplier_name do |instance, _|
      instance.supplier ? instance.supplier.name : nil
    end
    expose :category_subs do |instance, _|
      instance.category_subs.map { |cs| Entities::CategorySub.represent(cs).as_json }
    end
    expose :play_count
    expose :is_free
  end
end
