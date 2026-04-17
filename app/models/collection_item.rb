# frozen_string_literal: true

# 合集项模型
# 管理合集与图书的关联关系
class CollectionItem < ApplicationRecord
  # 关联关系
  belongs_to :collection  # 所属合集
  belongs_to :book        # 关联图书

  # 验证规则
  validates :collection_id, uniqueness: { scope: :book_id, message: "该图书已在合集中" }
  validates :sort_order, presence: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
end
