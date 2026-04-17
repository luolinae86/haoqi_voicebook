# frozen_string_literal: true

# 分类模型
# 管理图书分类，支持树形结构（如：学校推荐、作文、英语、科普百科、文学名著等）
class Category < ApplicationRecord
  # 自引用关联 - 支持树形分类结构
  belongs_to :parent, class_name: "Category", optional: true  # 父分类
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :destroy  # 子分类
  has_many :books, dependent: :nullify  # 该分类下的图书

  # 验证规则
  validates :name, presence: true  # 分类名称必填
  validates :sort_order, presence: true  # 排序必填

  # 排序作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :roots, -> { where(parent_id: nil) }  # 顶级分类
end
