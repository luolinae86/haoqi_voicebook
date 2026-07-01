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
      # 去重：相同 book_id + page_number + duration_seconds 在 1 秒内不重复创建
      recent_duplicate = ReadingSession.where(
        app_user: @app_user,
        book: @book,
        page_number: @page_number,
        duration_seconds: @duration_seconds,
        word_count: @word_count
      ).where('created_at >= ?', 1.second.ago).exists?

      return if recent_duplicate

      @reading_session = ReadingSession.create!(
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
      # 使用 upsert 避免并发时的唯一索引冲突
      attempts = 0
      begin
        attempts += 1
        progress = ReadingProgress.find_or_initialize_by(
          app_user_id: @app_user.id,
          book_id: @book.id
        )

        @user_new_book_read = progress.new_record?

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
      rescue ActiveRecord::RecordNotUnique
        # 并发时另一个请求已创建记录，重新查找并更新
        retry if attempts < 3
        raise
      end
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

      # 用刚创建的 session 判断是否是该书今天第一次阅读，避免并发竞态
      if stats.books_read_count.zero? &&
         @app_user.reading_sessions.by_book_and_date(@book, today).count == 1
        stats.books_read_count += 1
      end

      stats.save!
    end

    def update_book_stats
      stats = BookStats.find_or_create_for(@book.id)

      # 用刚创建的 session 判断是否是今天第一次读这本书，避免并发竞态
      if @app_user.reading_sessions.by_book_and_date(@book, Date.today.to_s).count == 1
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
                         .recently_completed(@app_user.id, since: Time.current - 1.minute)
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
