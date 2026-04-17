# frozen_string_literal: true

# 推荐项模型
# 管理推荐栏目与图书的关联关系
class RecommendationItem < ApplicationRecord
  # 关联关系
  belongs_to :recommendation  # 所属推荐
  belongs_to :book            # 关联图书

  # 验证规则
  validates :recommendation_id, uniqueness: { scope: :book_id, message: "该图书已在推荐中" }
  validates :sort_order, presence: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
end
