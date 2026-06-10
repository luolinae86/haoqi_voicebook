# frozen_string_literal: true

# == Schema Information
#
# Table name: catalogues
#
#  id                          :bigint           not null, primary key
#  chapter_name(章节名称)      :string(255)      not null
#  chapter_number(章节序号)    :integer          not null
#  is_free(是否免费)           :boolean          default(FALSE), not null
#  start_page_number(起始页码) :integer          not null
#  word_count(章节字数)        :integer          default(0), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  book_id(图书ID)             :bigint           not null
#
# Indexes
#
#  index_catalogues_on_book_id  (book_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
require 'rails_helper'

RSpec.describe Catalogue, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:book) }
  end

  describe 'scopes' do
    it 'returns chapters ordered by chapter_number' do
      book = create(:book)
      create(:catalogue, book: book, chapter_number: 2, chapter_name: '第二章', start_page_number: 20)
      create(:catalogue, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1)

      expect(Catalogue.ordered.map(&:chapter_number)).to eq([1, 2])
    end

    it 'filters chapters by start_page_number' do
      book = create(:book)
      chapter = create(:catalogue, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 10)
      create(:catalogue, book: book, chapter_number: 2, chapter_name: '第二章', start_page_number: 20)

      expect(Catalogue.by_start_page(10)).to include(chapter)
      expect(Catalogue.by_start_page(10).size).to eq(1)
    end
  end

  describe 'word_count' do
    it 'defaults to 0' do
      book = create(:book)
      chapter = create(:catalogue, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1)

      expect(chapter.word_count).to eq(0)
    end

    it 'can be set and read' do
      book = create(:book)
      chapter = create(:catalogue, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1, word_count: 1500)

      expect(chapter.word_count).to eq(1500)
    end
  end

  describe 'calculated_word_count' do
    it 'sums word_count from ebook_pages between current and next catalogue' do
      book = create(:book, content_file_type: 'epub')
      create(:catalogue, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1)
      create(:catalogue, book: book, chapter_number: 2, chapter_name: '第二章', start_page_number: 3)
      create(:ebook_page, book: book, page_number: 1, word_count: 100)
      create(:ebook_page, book: book, page_number: 2, word_count: 200)
      create(:ebook_page, book: book, page_number: 3, word_count: 500)

      first_catalogue = book.catalogues.find_by(chapter_number: 1)
      expect(first_catalogue.calculated_word_count).to eq(300)
    end

    it 'includes all pages from last catalogue onwards' do
      book = create(:book, content_file_type: 'epub')
      create(:catalogue, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1)
      create(:ebook_page, book: book, page_number: 1, word_count: 100)
      create(:ebook_page, book: book, page_number: 2, word_count: 200)
      create(:ebook_page, book: book, page_number: 3, word_count: 50)

      last_catalogue = book.catalogues.find_by(chapter_number: 1)
      expect(last_catalogue.calculated_word_count).to eq(350)
    end
  end
end
