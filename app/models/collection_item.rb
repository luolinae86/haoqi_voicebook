# == Schema Information
#
# Table name: collection_items
#
#   id                   integer(8)         not null, primary key
#   collection_id        integer(4)         not null
#   book_id              integer(4)         not null
#   sort_order           integer(4)         not null, default(0)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_collection_items_on_collection_id_and_book_id on collection_id, book_id (unique)
#  Index: index_collection_items_on_collection_id on collection_id
#  Index: index_collection_items_on_book_id on book_id
#
#
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
