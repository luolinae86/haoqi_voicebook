# frozen_string_literal: true

# == Schema Information
#
# Table name: head_imgs
#
#  id                      :bigint           not null, primary key
#  img_url(头像URL)        :string(255)
#  is_vip(是否VIP用户可用) :boolean          default(FALSE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
FactoryBot.define do
  factory :head_img do
    img_url { "https://bucket.oss-cn-beijing.aliyuncs.com/test/avatar.png" }
    is_vip { false }
  end
end
