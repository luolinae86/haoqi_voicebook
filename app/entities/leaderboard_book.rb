# frozen_string_literal: true

module Entities
  class LeaderboardBook < Grape::Entity
    expose :id
    expose :name
    expose :cover_image_url do |instance, _|
      Book.sign_oss_url(instance.cover_image_url)
    end
    expose :author_name do |instance, _|
      instance.author ? instance.author.name : nil
    end
    expose :content_description
    expose :category_name do |instance, _|
      instance.category ? instance.category.name : nil
    end
    expose :grade_name do |instance, _|
      instance.grades.first&.name
    end
    expose :content_type
    expose :is_free
  end
end
