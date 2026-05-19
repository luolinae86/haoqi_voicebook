# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reading::TrackService do
  let(:user) { create(:app_user) }
  let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 10) }

  describe '#call' do
    it 'creates a reading session' do
      expect { track_reading }.to change { ReadingSession.count }.by(1)

      session = ReadingSession.last
      expect(session.app_user_id).to eq(user.id)
      expect(session.book_id).to eq(book.id)
      expect(session.page_number).to eq(5)
      expect(session.word_count).to eq(200)
      expect(session.duration_seconds).to eq(120)
      expect(session.read_date).to eq(Date.today.to_s)
    end

    it 'creates reading progress for the book' do
      expect { track_reading }.to change { ReadingProgress.count }.by(1)

      progress = ReadingProgress.find_by(app_user_id: user.id, book_id: book.id)
      expect(progress.last_page_number).to eq(5)
      expect(progress.total_words_read).to eq(200)
      expect(progress.session_count).to eq(1)
      expect(progress.completed).to be false
    end

    it 'updates existing progress on second read' do
      track_reading
      track_reading

      progress = ReadingProgress.find_by(app_user_id: user.id, book_id: book.id)
      expect(progress.session_count).to eq(2)
      expect(progress.total_words_read).to eq(400)
    end

    it 'marks progress as completed when reaching last page' do
      Reading::TrackService.new(
        app_user: user,
        book: book,
        page_number: 10,
        word_count: 500,
        duration_seconds: 300
      ).call

      progress = ReadingProgress.find_by(app_user_id: user.id, book_id: book.id)
      expect(progress.completed).to be true
      expect(progress.completed_at).to be_present
    end

    it 'updates daily stats' do
      expect { track_reading }.to change { UserReadingDailyStats.count }.by(1)

      stats = UserReadingDailyStats.find_by(app_user_id: user.id, stat_date: Date.today.to_s)
      expect(stats.session_count).to eq(1)
      expect(stats.total_words_read).to eq(200)
      expect(stats.total_duration_seconds).to eq(120)
    end

    it 'creates book stats' do
      expect { track_reading }.to change { BookStats.count }.by(1)

      stats = BookStats.find_by(book_id: book.id)
      expect(stats.total_readers).to eq(1)
      expect(stats.total_reads).to eq(1)
      expect(stats.weekly_readers).to eq(1)
    end

    it 'does not double-count readers on same day' do
      track_reading
      track_reading

      stats = BookStats.find_by(book_id: book.id)
      expect(stats.total_readers).to eq(1)
      expect(stats.total_reads).to eq(2)
    end

    it 'updates user cumulative stats' do
      user.reload
      old_words = user.reading_words
      old_minutes = user.reading_minutes

      track_reading

      user.reload
      expect(user.reading_words).to eq(old_words + 200)
    end

    it 'increments books_read on first read of a book' do
      user.reload
      old_books = user.books_read

      track_reading

      user.reload
      expect(user.books_read).to eq(old_books + 1)
    end

    it 'does not increment books_read on second read of same book' do
      track_reading
      user.reload
      old_books = user.books_read

      track_reading

      user.reload
      expect(user.books_read).to eq(old_books)
    end
  end

  def track_reading
    Reading::TrackService.new(
      app_user: user,
      book: book,
      page_number: 5,
      word_count: 200,
      duration_seconds: 120
    ).call
  end
end
