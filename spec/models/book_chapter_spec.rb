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
require 'rails_helper'

RSpec.describe BookChapter, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:book) }
  end

  describe 'scopes' do
    it 'returns chapters ordered by chapter_number' do
      book = create(:book)
      create(:book_chapter, book: book, chapter_number: 2, chapter_name: '第二章', start_page_number: 20)
      create(:book_chapter, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1)

      expect(BookChapter.ordered.map(&:chapter_number)).to eq([1, 2])
    end

    it 'filters chapters by start_page_number' do
      book = create(:book)
      chapter = create(:book_chapter, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 10)
      create(:book_chapter, book: book, chapter_number: 2, chapter_name: '第二章', start_page_number: 20)

      expect(BookChapter.by_start_page(10)).to include(chapter)
      expect(BookChapter.by_start_page(10).size).to eq(1)
    end
  end

  describe 'word_count' do
    it 'defaults to 0' do
      book = create(:book)
      chapter = create(:book_chapter, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1)

      expect(chapter.word_count).to eq(0)
    end

    it 'can be set and read' do
      book = create(:book)
      chapter = create(:book_chapter, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1, word_count: 1500)

      expect(chapter.word_count).to eq(1500)
    end
  end
end
