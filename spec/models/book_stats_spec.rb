# frozen_string_literal: true

# == Schema Information
#
# Table name: book_stats
#
#  book_id              :bigint           not null, comment: '图书ID'
#  total_readers        :integer          not null, default(0), comment: '总阅读人数(去重)'
#  total_reads          :integer          not null, default(0), comment: '总阅读次数'
#  total_duration_seconds :integer       not null, default(0), comment: '总阅读时长(秒)'
#  total_words_read     :integer          not null, default(0), comment: '总阅读字数'
#  completed_count      :integer          not null, default(0), comment: '完读人数'
#  completion_rate      :float            not null, default(0.0), comment: '完读率'
#  weekly_readers       :integer          not null, default(0), comment: '近7天阅读人数'
#  weekly_reads         :integer          not null, default(0), comment: '近7天阅读次数'
#  monthly_readers      :integer          not null, default(0), comment: '近30天阅读人数'
#  monthly_reads        :integer          not null, default(0), comment: '近30天阅读次数'
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
