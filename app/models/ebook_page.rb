# frozen_string_literal: true

# 电子书页面模型
# 存储每一页的结构化富文本和图片块
class EbookPage < ApplicationRecord
  belongs_to :book

  validates :page_number, presence: true, uniqueness: { scope: :book_id }
  validates :page_width, :page_height, presence: true
  validates :word_count, :block_count, :image_count, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(page_number: :asc) }
end
