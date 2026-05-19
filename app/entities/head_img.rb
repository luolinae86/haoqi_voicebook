# frozen_string_literal: true

module Entities
  class HeadImg < Grape::Entity
    expose :id
    expose :img_url do |instance, _|
      Book.sign_oss_url(instance.img_url)
    end
    expose :is_vip
  end
end
