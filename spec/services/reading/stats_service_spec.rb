# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reading::StatsService do
  let(:user) { create(:app_user) }

  describe '.user_stats' do
    it 'returns zero stats for new user' do
      stats = described_class.user_stats(user)
      expect(stats[:total_books]).to eq(0)
      expect(stats[:completed_books]).to eq(0)
      expect(stats[:total_reading_minutes]).to eq(0)
      expect(stats[:consecutive_days]).to eq(0)
    end

    it 'returns correct stats after reading' do
      book = create(:book, page_count: 10)
      create(:reading_progress, app_user: user, book: book,
                                last_page_number: 5, total_duration_seconds: 300,
                                total_words_read: 500, session_count: 2)
      user.update(reading_words: 500, reading_minutes: 5)

      stats = described_class.user_stats(user)
      expect(stats[:total_books]).to eq(1)
      expect(stats[:total_reading_words]).to eq(500)
    end
  end

  describe '.book_stats' do
    it 'returns default stats when no record exists' do
      book = create(:book)
      stats = described_class.book_stats(book)
      expect(stats[:total_readers]).to eq(0)
      expect(stats[:total_reads]).to eq(0)
    end

    it 'returns actual stats when record exists' do
      book = create(:book)
      create(:book_stats, book: book, total_readers: 5, total_reads: 12, total_duration_seconds: 600)
      stats = described_class.book_stats(book)
      expect(stats[:total_readers]).to eq(5)
      expect(stats[:total_reads]).to eq(12)
      expect(stats[:total_reading_minutes]).to eq(10)
    end
  end

  describe '.user_progress' do
    it 'returns empty array for new user' do
      expect(described_class.user_progress(user)).to eq([])
    end

    it 'returns progress with book info' do
      book = create(:book, name: '测试图书', page_count: 50)
      create(:reading_progress, app_user: user, book: book, last_page_number: 10)
      progress = described_class.user_progress(user)
      expect(progress.first[:book_name]).to eq('测试图书')
      expect(progress.first[:last_page_number]).to eq(10)
    end

    it 'handles book without cover image without crashing' do
      book = create(:book, name: '无封面', cover_image_url: nil)
      create(:reading_progress, app_user: user, book: book, last_page_number: 3)
      expect { described_class.user_progress(user) }.not_to raise_error
    end
  end

  describe '.user_book_progress' do
    it 'returns nil for unread book' do
      book = create(:book)
      expect(described_class.user_book_progress(user, book.id)).to be_nil
    end

    it 'returns progress for read book' do
      book = create(:book)
      create(:reading_progress, app_user: user, book: book, last_page_number: 8, session_count: 3)
      result = described_class.user_book_progress(user, book.id)
      expect(result[:last_page_number]).to eq(8)
    end
  end

  describe '.chart_data' do
    it 'week returns 7 days' do
      data = described_class.chart_data(user, period: 'week')
      expect(data[:daily].size).to eq(7)
    end

    it 'month returns 4 weeks' do
      data = described_class.chart_data(user, period: 'month')
      expect(data[:weekly].size).to eq(4)
    end

    it 'all zeros when no records' do
      data = described_class.chart_data(user, period: 'week')
      expect(data[:daily].all? { |d| d[:minutes] == 0 }).to be true
    end

    it 'correct minutes when records exist for week' do
      create(:user_reading_daily_stats, app_user: user, stat_date: Date.today.to_s, total_duration_seconds: 900)
      data = described_class.chart_data(user, period: 'week')
      today_entry = data[:daily].find { |d| d[:date] == Date.today.to_s }
      expect(today_entry[:minutes]).to eq(15)
    end

    it 'correct weekly minutes when records exist for month' do
      # 本周（最近 7 天）的某一天有阅读记录
      today = Date.today
      create(:user_reading_daily_stats, app_user: user, stat_date: today.to_s, total_duration_seconds: 1800)

      data = described_class.chart_data(user, period: 'month')
      # 最后一周（本周）应该包含今天的记录（数组按时间升序排列）
      this_week = data[:weekly].last
      expect(this_week[:minutes]).to be >= 30
    end
  end
end
