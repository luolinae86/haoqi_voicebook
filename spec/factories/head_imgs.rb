# frozen_string_literal: true

FactoryBot.define do
  factory :head_img do
    img_url { "https://bucket.oss-cn-beijing.aliyuncs.com/test/avatar.png" }
    is_vip { false }
  end
end
