# frozen_string_literal: true

# == Schema Information
#
# Table name: category_subs
#
#  id                    :bigint           not null, primary key
#  icon(图标URL)         :string(255)
#  name(子类名称)        :string(255)      not null
#  sn(排序)              :integer          default(0)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  category_id(关联分类) :bigint           not null
#
# Indexes
#
#  index_category_subs_on_category_id  (category_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
FactoryBot.define do
  factory :category_sub do
    association :category
    name { "子类#{Faker::Number.number(digits: 2)}" }
    sn { 0 }
  end
end
