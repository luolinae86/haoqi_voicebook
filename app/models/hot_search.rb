# == Schema Information
#
# Table name: hot_searches
#
#   id                   integer(8)         not null, primary key
#   keyword              string(255)        not null
#   search_count         integer(4)         not null, default(0)
#   sort_order           integer(4)         not null, default(0)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_hot_searches_on_keyword on keyword (unique)
#  Index: index_hot_searches_on_sort_order on sort_order
#
#
# frozen_string_literal: true

# 热门搜索模型
# 管理搜索页面展示的热门搜索关键词
class HotSearch < ApplicationRecord
  # 验证规则
  validates :keyword, presence: true, uniqueness: true
  validates :sort_order, presence: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :popular, -> { order(search_count: :desc) }

  # 增加搜索次数
  def increment_count!
    increment!(:search_count)
  end
end
