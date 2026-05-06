# frozen_string_literal: true

# 年级模型
# 管理学生年级信息，包括学龄前、小学、初中、高中各年级
class Grade < ApplicationRecord
  # 关联关系
  has_many :app_users, class_name: "AppUser", foreign_key: "grade_id", dependent: :nullify          # 该年级下的用户
  has_many :books, dependent: :nullify          # 该年级推荐的图书
  has_many :collections, dependent: :nullify, foreign_key: :target_grade_id # 该年级的合集
  has_many :recommendations, dependent: :nullify, foreign_key: :target_grade_id # 该年级的推荐

  # 验证规则
  validates :name, presence: true, uniqueness: true  # 年级名称必填且唯一
  validates :level, presence: true, uniqueness: true  # 年级等级必填且唯一
  validates :sort_order, presence: true               # 排序必填

  # 排序作用域
  scope :ordered, -> { order(sort_order: :asc) }
end
