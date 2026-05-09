# == Schema Information
#
# Table name: rankings
#
#   id                   integer(8)         not null, primary key
#   name                 string(255)        not null
#   ranking_type         integer(4)         not null, default(0)
#   description          string(255)        
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_rankings_on_ranking_type on ranking_type
#
#
# frozen_string_literal: true

# 排行榜模型
# 管理各类排行榜（热度榜、高分榜、上新榜、大奖榜、名著榜）
class Ranking < ApplicationRecord
  # 排行榜类型枚举
  enum :ranking_type, { hot: 0, high_score: 1, new_arrival: 2, award: 3, classic: 4 }, default: :hot

  # 关联关系
  has_many :ranking_items, dependent: :destroy # 排行项
  has_many :books, through: :ranking_items # 上榜图书

  # 验证规则
  validates :name, presence: true
  validates :ranking_type, presence: true
end
