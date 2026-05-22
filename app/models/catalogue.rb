# frozen_string_literal: true

# == Schema information
#
# Table name: catalogues
#
#  id                                :bigint           not null, primary key
#  book_id                           :bigint           not null, comment: '图书ID'
#  chapter_number                    :integer          not null, comment: '章节序号'
#  chapter_name                      :string           not null, comment: '章节名称'
#  start_page_number                 :integer          not null, comment: '起始页码'
#  is_free(是否免费)                  :boolean          default(FALSE), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#
# Indexes
#
#  index_catalogues_on_book_id  (book_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
class Catalogue < ApplicationRecord
  belongs_to :book

  scope :ordered, -> { order(:chapter_number) }
  scope :by_start_page, ->(page_number) { where(start_page_number: page_number) }

  # 计算章节字数：从当前章节起始页到下一章起始页之间所有 ebook_pages 的 word_count 总和
  def calculated_word_count
    pages = book.ebook_pages.where("page_number >= ?", start_page_number)
    next_catalogue = book.catalogues
                       .where("start_page_number > ?", start_page_number)
                       .order(:start_page_number)
                       .first
    pages = pages.where("page_number < ?", next_catalogue.start_page_number) if next_catalogue

    pages.sum(:word_count)
  end
end
