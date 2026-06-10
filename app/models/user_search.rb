# frozen_string_literal: true

# == Schema Information
#
# Table name: user_searches
#
#  id                  :bigint           not null, primary key
#  keyword(搜索关键词) :string(255)      not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  app_user_id         :bigint           not null
#
# Indexes
#
#  index_user_searches_on_app_user_id                 (app_user_id)
#  index_user_searches_on_app_user_id_and_created_at  (app_user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (app_user_id => app_users.id)
#
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
