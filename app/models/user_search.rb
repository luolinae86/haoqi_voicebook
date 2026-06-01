# frozen_string_literal: true

class UserSearch < ApplicationRecord
  belongs_to :app_user

  # 获取全局搜索最多的关键词（按搜索次数降序）
  scope :top_keywords, ->(limit = 10) {
    select('keyword, COUNT(*) as count')
      .group(:keyword)
      .order(Arel.sql('count DESC'))
      .limit(limit)
  }
end
