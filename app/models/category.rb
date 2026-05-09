# == Schema Information
#
# Table name: categories
#
#   id                   integer(8)         not null, primary key
#   name                 string(255)        not null
#   parent_id            integer(4)         
#   sort_order           integer(4)         not null, default(0)
#   icon                 string(255)        
#   description          string(255)        
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_categories_on_parent_id on parent_id
#  Index: index_categories_on_sort_order on sort_order
#
#
# frozen_string_literal: true

# 分类模型
# 管理图书分类，支持树形结构（如：学校推荐、作文、英语、科普百科、文学名著等）
class Category < ApplicationRecord
  # 自引用关联 - 支持树形分类结构
  belongs_to :parent, class_name: "Category", optional: true # 父分类
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :destroy # 子分类
  has_many :books, dependent: :nullify # 该分类下的图书

  # 验证规则
  validates :name, presence: true # 分类名称必填
  validates :sort_order, presence: true # 排序必填

  # 排序作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :roots, -> { where(parent_id: nil) }
  scope :by_parent, ->(parent_id) { where(parent_id: parent_id) } # 顶级分类
end
