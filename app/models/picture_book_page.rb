# frozen_string_literal: true

# 绘本（picture_book）逐页数据：页图、OCR 文本、朗读窗口与行/token。
# 一本绘本的完整渲染结果同时会导出为 book.json/dict.json 存 OSS，这里是可查询的真相。
class PictureBookPage < ApplicationRecord
  belongs_to :book

  validates :page_number, presence: true, uniqueness: { scope: :book_id }

  scope :ordered, -> { order(page_number: :asc) }
end
