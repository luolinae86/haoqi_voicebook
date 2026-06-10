# frozen_string_literal: true

# == Schema Information
#
# Table name: book_stats(图书统计表)
#
#  id                                     :bigint           not null, primary key
#  completed_count(完读人数)              :integer          default(0), not null
#  completion_rate(完读率)                :float(24)        default(0.0), not null
#  monthly_readers(近30天阅读人数)        :integer          default(0), not null
#  monthly_reads(近30天阅读次数)          :integer          default(0), not null
#  total_duration_seconds(总阅读时长(秒)) :integer          default(0), not null
#  total_readers(总阅读人数(去重))        :integer          default(0), not null
#  total_reads(总阅读次数)                :integer          default(0), not null
#  total_words_read(总阅读字数)           :integer          default(0), not null
#  weekly_readers(近7天阅读人数)          :integer          default(0), not null
#  weekly_reads(近7天阅读次数)            :integer          default(0), not null
#  created_at                             :datetime         not null
#  updated_at                             :datetime         not null
#  book_id(图书ID)                        :bigint           not null
#
# Indexes
#
#  index_book_stats_on_book_id          (book_id) UNIQUE
#  index_book_stats_on_monthly_readers  (monthly_readers)
#  index_book_stats_on_weekly_readers   (weekly_readers)
#
require 'rails_helper'

RSpec.describe BookStats, type: :model do
  describe 'associations' do
    it 'belongs to book' do
      expect(BookStats.reflect_on_association(:book)).to be_present
    end
  end

  describe 'scopes' do
    it 'orders by weekly_readers descending' do
      book1 = create(:book)
      book2 = create(:book)
      create(:book_stats, book: book1, weekly_readers: 10)
      create(:book_stats, book: book2, weekly_readers: 50)

      expect(BookStats.by_weekly_readers.first.weekly_readers).to eq(50)
    end

    it 'orders by monthly_readers descending' do
      book1 = create(:book)
      book2 = create(:book)
      create(:book_stats, book: book1, monthly_readers: 5)
      create(:book_stats, book: book2, monthly_readers: 100)

      expect(BookStats.by_monthly_readers.first.monthly_readers).to eq(100)
    end
  end

  describe '.find_or_create_for' do
    it 'creates stats for a new book' do
      book = create(:book)
      stats = BookStats.find_or_create_for(book.id)
      expect(stats.book_id).to eq(book.id)
      expect(stats.total_readers).to eq(0)
    end

    it 'returns existing stats' do
      book = create(:book)
      existing = BookStats.create!(book_id: book.id)
      expect(BookStats.find_or_create_for(book.id)).to eq(existing)
    end
  end
end
