# == Schema Information
#
# Table name: ranking_items
#
#   id                   integer(8)         not null, primary key
#   ranking_id           integer(4)         not null
#   book_id              integer(4)         not null
#   rank                 integer(4)         not null
#   score                decimal            default(0.00)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_ranking_items_on_ranking_id_and_book_id on ranking_id, book_id (unique)
#  Index: index_ranking_items_on_ranking_id on ranking_id
#  Index: index_ranking_items_on_book_id on book_id
#  Index: index_ranking_items_on_ranking_id_and_rank on ranking_id, rank
#
#
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
