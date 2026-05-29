# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Create fake reading progress data for a specific user"
    task reading_progress_for_user: :environment do
      uuid = ENV.fetch("UUID", "15d77adba95447d4ace3a060adbe77a0")

      user = AppUser.find_by(uuid: uuid)
      if user.blank?
        puts "ERROR: User with uuid=#{uuid} not found"
        exit 1
      end

      puts "Found user: id=#{user.id}, uuid=#{user.uuid}"

      # Get published books with page_count > 0
      books = Book.published_books.where('page_count > 0').order(id: :desc).limit(10).to_a
      if books.empty?
        puts "ERROR: No published books with page_count > 0 found"
        exit 1
      end

      puts "Using #{books.size} published books (with page_count > 0)"
      books.each { |b| puts "  - #{b.name} (#{b.page_count} pages)" }

      # Clear existing progress for this user
      user.reading_progresses.destroy_all
      puts "Cleared existing reading progresses"

      # Create reading progress for each available book (max 5)
      books_to_use = books.first(5)
      scenarios = []

      books_to_use.each_with_index do |book, idx|
        case idx
        when 0
          # Reading in progress - page ~30% through
          page = [(book.page_count * 0.3).floor, 1].max
          scenarios << { last_page: page, completed: false, label: 'reading', words: book.word_count / 3, duration: 600, sessions: 3, time: 2.hours.ago }
        when 1
          # Completed book
          scenarios << { last_page: book.page_count, completed: true, label: 'completed', words: book.word_count, duration: 1800, sessions: 5, time: 1.day.ago, completed_at: 1.day.ago }
        when 2
          # Just started - only a few pages in
          page = [3, book.page_count].min
          scenarios << { last_page: page, completed: false, label: 'started', words: 500, duration: 180, sessions: 1, time: 30.minutes.ago }
        when 3
          # Halfway through
          page = [(book.page_count / 2.0).floor, 1].max
          scenarios << { last_page: page, completed: false, label: 'halfway', words: book.word_count / 2, duration: 900, sessions: 4, time: 5.hours.ago }
        when 4
          # Another completed book
          scenarios << { last_page: book.page_count, completed: true, label: 'completed', words: book.word_count, duration: 2400, sessions: 8, time: 2.days.ago, completed_at: 2.days.ago }
        end
      end

      books_to_use.each_with_index do |book, idx|
        s = scenarios[idx]
        ReadingProgress.create!(
          app_user: user,
          book: book,
          last_page_number: s[:last_page],
          total_words_read: s[:words],
          total_duration_seconds: s[:duration],
          session_count: s[:sessions],
          completed: s[:completed],
          completed_at: s[:completed_at],
          last_read_at: s[:time]
        )
        puts "  [#{s[:label]}] #{book.name} - page #{s[:last_page]}/#{book.page_count}"
      end

      puts ""
      puts "=== Summary ==="
      puts "Total reading progresses: #{user.reading_progresses.count}"
      puts "Completed: #{user.reading_progresses.completed.count}"
      puts "In progress: #{user.reading_progresses.in_progress.count}"
      puts "Done!"
    end
  end
end
