# frozen_string_literal: true

# == Schema Information
#
# Table name: book_chapters
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
#  index_book_chapters_on_book_id  (book_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
class BookChapter < ApplicationRecord
  belongs_to :book

  scope :ordered, -> { order(:chapter_number) }
end
