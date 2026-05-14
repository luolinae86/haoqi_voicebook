# frozen_string_literal: true

# == Schema Information
#
# Table name: compilations
#
#  id                                                      :bigint           not null, primary key
#  author(作者)                                            :string(255)
#  banner_image_name(合辑banner图片文件名)                 :string(255)
#  banner_image_url(合辑banner图片URL (1500x932, <=500KB)) :string(255)
#  content_description(合辑简介（富文本/Markdown）)        :text(65535)
#  description(内容简介)                                   :text(65535)
#  editor_recommendation(编辑推荐语（15字以内）)           :string(15)
#  intro_image_name(图片简介文件名)                        :string(255)
#  intro_image_url(图片简介URL)                            :string(255)
#  landscape_cover_name(横图封面文件名)                    :string(255)
#  landscape_cover_url(横图封面URL (1125x540, <=500KB))    :string(255)
#  name(合辑名称)                                          :string(255)      not null
#  portrait_cover_name                                     :string(255)
#  portrait_cover_url                                      :string(255)
#  publisher(出版社)                                       :string(255)
#  square_cover_name                                       :string(255)
#  square_cover_url                                        :string(255)
#  tags(内容标签)                                          :string(255)
#  total_count(合辑总集数)                                 :integer          default(0)
#  created_at                                              :datetime         not null
#  updated_at                                              :datetime         not null
#
# Indexes
#
#  index_compilations_on_name  (name) UNIQUE
#
FactoryBot.define do
  factory :compilation do
    name { "合辑#{Faker::Number.number(digits: 3)}" }
    publisher { "测试出版社" }
    total_count { 0 }
  end
end
