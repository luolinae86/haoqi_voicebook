# frozen_string_literal: true

# 章节模型
# 管理图书的章节内容，支持免费/VIP 区分
class Chapter < ApplicationRecord
  # 关联关系
  belongs_to :book  # 所属图书

  # 验证规则
  validates :title, presence: true          # 章节标题必填
  validates :sort_order, presence: true     # 排序必填
  validates :word_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :free_chapters, -> { where(is_free: true) }
  scope :vip_chapters, -> { where(is_vip: true) }
end
