# frozen_string_literal: true

# 排行项模型
# 管理排行榜中的图书排名
class RankingItem < ApplicationRecord
  # 关联关系
  belongs_to :ranking  # 所属排行榜
  belongs_to :book     # 关联图书

  # 验证规则
  validates :rank, presence: true, numericality: { greater_than: 0 }
  validates :ranking_id, uniqueness: { scope: :book_id, message: "该图书已在排行榜中" }

  # 作用域
  scope :ordered, -> { order(rank: :asc) }
end
