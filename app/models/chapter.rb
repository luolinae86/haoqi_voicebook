# == Schema Information
#
# Table name: chapters
#
#   id                   integer(8)         not null, primary key
#   book_id              integer(4)         not null
#   title                string(255)        not null
#   sort_order           integer(4)         not null, default(0)
#   content              text(65535)        
#   is_free              boolean            not null, default(0)
#   is_vip               boolean            not null, default(0)
#   word_count           integer(4)         not null, default(0)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_chapters_on_book_id on book_id
#  Index: index_chapters_on_book_id_and_sort_order on book_id, sort_order
#
#
# frozen_string_literal: true

# 章节模型
# 管理图书的章节内容，支持免费/VIP 区分
class Chapter < ApplicationRecord
  # 关联关系
  belongs_to :book # 所属图书

  # 验证规则
  validates :title, presence: true          # 章节标题必填
  validates :sort_order, presence: true     # 排序必填
  validates :word_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :free_chapters, -> { where(is_free: true) }
  scope :vip_chapters, -> { where(is_vip: true) }
end
