# == Schema Information
#
# Table name: recommendations
#
#   id                   integer(8)         not null, primary key
#   title                string(255)        not null
#   description          text(65535)        
#   recommendation_type  integer(4)         not null, default(0)
#   target_grade_id      integer(4)         
#   sort_order           integer(4)         not null, default(0)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_recommendations_on_recommendation_type on recommendation_type
#  Index: index_recommendations_on_target_grade_id on target_grade_id
#  Index: index_recommendations_on_sort_order on sort_order
#
#
# frozen_string_literal: true

# 推荐模型
# 管理首页推荐栏目（如：童年金典、选对名著、成长好伙伴等）
class Recommendation < ApplicationRecord
  # 推荐类型枚举
  enum :recommendation_type, { featured: 0, graded: 1, trending: 2, new_book: 3, topic: 4 }, default: :featured

  # 关联关系
  belongs_to :target_grade, class_name: "Grade", optional: true # 目标年级
  has_many :recommendation_items, dependent: :destroy             # 推荐项
  has_many :books, through: :recommendation_items                 # 推荐的图书

  # 验证规则
  validates :title, presence: true
  validates :sort_order, presence: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :for_grade, ->(grade_id) { where(target_grade_id: [grade_id, nil]) }
  scope :by_type, ->(type) { where(recommendation_type: type) }
end
