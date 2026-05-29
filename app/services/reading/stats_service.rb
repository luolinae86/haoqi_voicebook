# frozen_string_literal: true

module Reading
  class StatsService
    # 获取用户阅读统计摘要
    def self.user_stats(app_user)
      Rails.cache.fetch("user_stats_#{app_user.id}", expires_in: 30.seconds) do
        total_books = app_user.reading_progresses.count
        completed_books = app_user.reading_progresses.completed.count
        total_seconds = app_user.reading_progresses.sum(:total_duration_seconds)
        total_sessions = app_user.reading_progresses.sum(:session_count)

        avg_duration = total_sessions > 0 ? total_seconds / total_sessions : 0
        completion_rate = total_books > 0 ? (completed_books.to_f / total_books * 100).round(1) : 0

        consecutive_days = app_user.consecutive_reading_days

        {
          total_books: total_books,
          completed_books: completed_books,
          total_reading_minutes: (total_seconds / 60.0).round,
          total_reading_words: app_user.reading_words,
          avg_reading_minutes: (avg_duration / 60.0).round(1),
          completion_rate: completion_rate,
          consecutive_days: consecutive_days
        }
      end
    end

    # 获取图书被阅读统计
    def self.book_stats(book)
      stats = BookStats.find_by(book_id: book.id)
      return default_book_stats if stats.blank?

      {
        total_readers: stats.total_readers,
        total_reads: stats.total_reads,
        total_reading_minutes: (stats.total_duration_seconds / 60.0).round,
        completed_count: stats.completed_count,
        completion_rate: (stats.completion_rate * 100).round(1),
        weekly_readers: stats.weekly_readers,
        monthly_readers: stats.monthly_readers
      }
    end

    # 获取用户阅读进度列表
    def self.user_progress(app_user, limit: 20)
      app_user.reading_progresses
              .includes(:book)
              .recently_read
              .limit(limit)
              .map { |p| progress_to_hash(p) }
    end

    # 获取用户某本书的阅读进度
    def self.user_book_progress(app_user, book_id)
      progress = app_user.reading_progresses.find_by(book_id: book_id)
      return nil if progress.blank?
      progress_to_hash(progress)
    end

    # 获取阅读时长图表数据（按周/月）
    def self.chart_data(app_user, period: 'week')
      days = period == 'month' ? 28 : 7
      stats = app_user.user_reading_daily_stats
        .last_n_days(days)
        .pluck(:stat_date, :total_duration_seconds)

      # 补齐缺失的日期（没有阅读记录的日期时长为 0）
      result = {}
      days.times do |i|
        date = (days - 1 - i).days.ago.to_date.to_s
        result[date] = 0
      end
      stats.each { |d, s| result[d] = (s.to_f / 60.0).round }

      # 返回按日期升序的数组
      total_minutes = result.values.sum
      {
        daily: result.sort.map { |date, minutes| { date: date, minutes: minutes } },
        total_minutes: total_minutes
      }
    end

    private

    def self.default_book_stats
      {
        total_readers: 0,
        total_reads: 0,
        total_reading_minutes: 0,
        completed_count: 0,
        completion_rate: 0,
        weekly_readers: 0,
        monthly_readers: 0
      }
    end

    def self.progress_to_hash(progress)
      {
        book_id: progress.book_id,
        book_name: progress.book&.name,
        cover_image_url: Book.sign_oss_url(progress.book&.cover_image_url),
        last_page_number: progress.last_page_number,
        total_pages: progress.book&.page_count,
        total_words_read: progress.total_words_read,
        session_count: progress.session_count,
        completed: progress.completed,
        last_read_at: progress.last_read_at&.strftime('%Y-%m-%d %H:%M:%S')
      }
    end
  end
end
