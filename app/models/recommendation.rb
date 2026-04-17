# frozen_string_literal: true

# 推荐模型
# 管理首页推荐栏目（如：童年金典、选对名著、成长好伙伴等）
class Recommendation < ApplicationRecord
  # 推荐类型枚举
  enum :recommendation_type, { featured: 0, graded: 1, trending: 2, new_book: 3, topic: 4 }, default: :featured

  # 关联关系
  belongs_to :target_grade, class_name: "Grade", optional: true  # 目标年级
  has_many :recommendation_items, dependent: :destroy             # 推荐项
  has_many :books, through: :recommendation_items                 # 推荐的图书

  # 验证规则
  validates :title, presence: true
  validates :sort_order, presence: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
end
