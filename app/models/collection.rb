# frozen_string_literal: true

# 专题合集模型
# 管理图书合集/专题（如：趣读书吧、国学金典、校园成长等）
class Collection < ApplicationRecord
  # 合集类型枚举
  enum :collection_type, { topic: 0, graded: 1, trending: 2, new_arrival: 3 }, default: :topic

  # 关联关系
  belongs_to :target_grade, class_name: "Grade", optional: true  # 目标年级
  has_many :collection_items, dependent: :destroy                 # 合集项
  has_many :books, through: :collection_items                     # 合集中的图书

  # 验证规则
  validates :title, presence: true        # 合集标题必填
  validates :sort_order, presence: true   # 排序必填

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :for_grade, ->(grade_id) { where(target_grade_id: [grade_id, nil]) }
  scope :by_type, ->(type) { where(collection_type: type) }
end
