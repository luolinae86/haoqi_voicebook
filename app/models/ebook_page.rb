# frozen_string_literal: true

# == Schema Information
#
# Table name: ebook_pages(电子书页面表)
#
#  id                             :bigint           not null, primary key
#  block_count(块数量)            :integer          default(0), not null
#  image_count(图片数量)          :integer          default(0), not null
#  page_height(页面高度(pt))      :decimal(8, 2)    not null
#  page_number(页码)              :integer          not null
#  page_width(页面宽度(pt))       :decimal(8, 2)    not null
#  plain_text(页面纯文本)         :text(65535)
#  rich_content(页面富文本块)     :json             not null
#  word_count(字数)               :integer          default(0), not null
#  xhtml_content(页面 XHTML 内容) :text(65535)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  book_id(图书ID)                :bigint           not null
#  chapter_id                     :bigint
#
# Indexes
#
#  index_ebook_pages_on_book_id                  (book_id)
#  index_ebook_pages_on_book_id_and_page_number  (book_id,page_number) UNIQUE
#  index_ebook_pages_on_chapter_id               (chapter_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#  fk_rails_...  (chapter_id => chapters.id)
#
class EbookPage < ApplicationRecord
  belongs_to :book
  belongs_to :chapter, optional: true

  validates :page_number, presence: true, uniqueness: { scope: :book_id }
  validates :page_width, :page_height, presence: true
  validates :word_count, :block_count, :image_count, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(page_number: :asc) }
  scope :before_page, ->(page_number) { where("page_number < ?", page_number) }
  scope :after_page, ->(page_number) { where("page_number > ?", page_number) }
end
