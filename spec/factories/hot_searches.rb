# frozen_string_literal: true

# == Schema Information
#
# Table name: hot_searches(热门搜索表)
#
#  id                     :bigint           not null, primary key
#  is_active(是否启用)    :boolean          default(TRUE), not null
#  keyword(关键词)        :string(255)      not null
#  search_count(搜索次数) :integer          default(0), not null
#  sort_order(排序)       :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_hot_searches_on_is_active_and_sort_order  (is_active,sort_order)
#  index_hot_searches_on_keyword                   (keyword) UNIQUE
#
FactoryBot.define do
  factory :hot_search do
    sequence(:keyword) { |n| "热门搜索词#{n}" }
    sort_order { 0 }
    is_active { true }
  end
end
