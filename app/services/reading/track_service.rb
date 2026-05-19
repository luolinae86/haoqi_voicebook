# frozen_string_literal: true

module Reading
  # 跟踪用户阅读行为并更新各项统计数据
  class TrackService
    class Error < StandardError; end

    def initialize(app_user:, book:, page_number:, word_count: 0, duration_seconds: 0)
      @app_user = app_user
      @book = book
      @page_number = page_number
      @word_count = word_count
      @duration_seconds = duration_seconds
    end

    def call
      return if @page_number.blank?

      ActiveRecord::Base.transaction do
        create_reading_session
        update_reading_progress
        update_daily_stats
        update_book_stats
        update_user_cumulative_stats
      end
    end

    private

    def create_reading_session
      ReadingSession.create!(
        app_user: @app_user,
        book: @book,
        page_number: @page_number,
        word_count: @word_count,
        duration_seconds: @duration_seconds,
        started_at: Time.current,
        read_date: Date.today.to_s
      )
    end

    def update_reading_progress
      progress = ReadingProgress.find_or_initialize_by(
        app_user_id: @app_user.id,
        book_id: @book.id
      )

      is_new_record = progress.new_record?

      if progress.last_page_number < @page_number
        progress.last_page_number = @page_number
      end

      progress.total_words_read += @word_count
      progress.total_duration_seconds += @duration_seconds
      progress.session_count += 1
      progress.last_read_at = Time.current

      # 检查是否完读（到达最后一页）
      if !progress.completed && @book.page_count > 0 && @page_number >= @book.page_count
        progress.completed = true
        progress.completed_at = Time.current
      end

      progress.save!

      # 如果是首次阅读这本书，增加用户 books_read
      @user_new_book_read = is_new_record
    end

    def update_daily_stats
      today = Date.today.to_s
      stats = UserReadingDailyStats.find_or_initialize_by(
        app_user_id: @app_user.id,
        stat_date: today
      )

      stats.session_count += 1
      stats.total_duration_seconds += @duration_seconds
      stats.total_words_read += @word_count

      # 如果今天还没读过这本书，增加 books_read_count
      unless stats.books_read_count.positive? &&
             @app_user.reading_sessions.where(book: @book, read_date: today).count > 1
        # 检查是否是该书今天的第一个 session
        first_session_today = @app_user.reading_sessions
                                       .where(book: @book, read_date: today)
                                       .order(:id).first
        if first_session_today && first_session_today.id == ReadingSession.order(:id).last&.id
          stats.books_read_count += 1
        end
      end

      stats.save!
    end

    def update_book_stats
      stats = BookStats.find_or_create_for(@book.id)

      # 检查该用户今天是否已经读过这本书（用于去重 readers）
      today_sessions = ReadingSession.where(
        app_user_id: @app_user.id,
        book_id: @book.id,
        read_date: Date.today.to_s
      )

      if today_sessions.count == 1
        # 今天第一次读这本书，增加 readers
        stats.total_readers += 1
        stats.weekly_readers += 1
        stats.monthly_readers += 1
      end

      stats.total_reads += 1
      stats.total_duration_seconds += @duration_seconds
      stats.total_words_read += @word_count
      stats.weekly_reads += 1
      stats.monthly_reads += 1

      # 如果用户刚完读这本书，增加完读人数
      if @book.reading_progresses
                         .where(app_user_id: @app_user.id, completed: true, completed_at: Time.current - 1.minute..)
                         .exists?
        stats.completed_count += 1
      end

      # 重新计算完读率
      stats.completion_rate = stats.total_readers > 0 ? (stats.completed_count.to_f / stats.total_readers) : 0.0

      stats.save!
    end

    def update_user_cumulative_stats
      @app_user.update_reading_stats!(
        words: @word_count,
        minutes: (@duration_seconds / 60.0).round,
        books: (@user_new_book_read ? 1 : 0)
      )
    end
  end
end
