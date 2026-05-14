# frozen_string_literal: true

# == Schema Information
#
# Table name: contents
#
#  id                             :bigint           not null, primary key
#  content_type(类型)             :string(255)      not null
#  img_url(图片链接)              :string(255)
#  sn(排序)                       :integer          default(0)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  author_id(作者信息)            :bigint
#  book_id(单本信息)              :bigint
#  compilation_id(合辑信息)       :bigint
#  content_group_id(关联内容分组) :bigint           not null
#  recommend_id(推荐信息)         :bigint
#
# Indexes
#
#  index_contents_on_content_group_id  (content_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (content_group_id => content_groups.id)
#
FactoryBot.define do
  factory :content do
    association :content_group
    content_type { "book" }
    sn { 0 }
  end
end
