# == Schema Information
#
# Table name: ebook_pages
#
#   id                   integer(8)         not null, primary key
#   book_id              integer(8)         not null
#   page_number          integer(4)         not null
#   page_width           decimal            not null
#   page_height          decimal            not null
#   plain_text           text(65535)        
#   rich_content         json               not null
#   word_count           integer(4)         not null, default(0)
#   block_count          integer(4)         not null, default(0)
#   image_count          integer(4)         not null, default(0)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#   xhtml_content        text(65535)        
#
#  Index: index_ebook_pages_on_book_id_and_page_number on book_id, page_number (unique)
#  Index: index_ebook_pages_on_book_id on book_id
#
#
# frozen_string_literal: true

# 电子书页面模型
# 存储每一页的结构化富文本和图片块
class EbookPage < ApplicationRecord
  belongs_to :book

  validates :page_number, presence: true, uniqueness: { scope: :book_id }
  validates :page_width, :page_height, presence: true
  validates :word_count, :block_count, :image_count, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(page_number: :asc) }
  scope :before_page, ->(page_number) { where("page_number < ?", page_number) }
  scope :after_page, ->(page_number) { where("page_number > ?", page_number) }
end
