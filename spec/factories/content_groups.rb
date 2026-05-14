# frozen_string_literal: true

# == Schema Information
#
# Table name: content_groups
#
#  id                     :bigint           not null, primary key
#  group_type(小组类型)   :string(255)      not null
#  name(小组名称)         :string(255)      not null
#  sn(排序)               :integer          default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  recommend_id(关联年级) :bigint           not null
#
# Indexes
#
#  index_content_groups_on_recommend_id  (recommend_id)
#
# Foreign Keys
#
#  fk_rails_...  (recommend_id => recommends.id)
#
FactoryBot.define do
  factory :content_group do
    association :recommend
    name { "内容分组#{Faker::Number.number(digits: 2)}" }
    group_type { "multi_images" }
    sn { 0 }
  end
end
