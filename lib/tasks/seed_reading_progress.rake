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

      # Get published books
      books = Book.published_books.limit(10).to_a
      if books.size < 5
        puts "ERROR: Need at least 5 published books, found #{books.size}"
        exit 1
      end

      puts "Using #{books.size} published books"

      # Clear existing progress for this user
      user.reading_progresses.destroy_all
      puts "Cleared existing reading progresses"

      # 1. Reading in progress - page 15 of a longer book
      b1 = books[0]
      ReadingProgress.create!(
        app_user: user,
        book: b1,
        last_page_number: [15, b1.page_count].min,
        total_words_read: 3000,
        total_duration_seconds: 600,
        session_count: 3,
        completed: false,
        last_read_at: 2.hours.ago
      )
      puts "  [reading] #{b1.name} - page #{[15, b1.page_count].min}/#{b1.page_count}"

      # 2. Completed book
      b2 = books[1]
      ReadingProgress.create!(
        app_user: user,
        book: b2,
        last_page_number: b2.page_count,
        total_words_read: b2.word_count,
        total_duration_seconds: 1800,
        session_count: 5,
        completed: true,
        completed_at: 1.day.ago,
        last_read_at: 1.day.ago
      )
      puts "  [completed] #{b2.name} - page #{b2.page_count}/#{b2.page_count}"

      # 3. Just started - only a few pages in
      b3 = books[2]
      ReadingProgress.create!(
        app_user: user,
        book: b3,
        last_page_number: [3, b3.page_count].min,
        total_words_read: 500,
        total_duration_seconds: 180,
        session_count: 1,
        completed: false,
        last_read_at: 30.minutes.ago
      )
      puts "  [started] #{b3.name} - page #{[3, b3.page_count].min}/#{b3.page_count}"

      # 4. Halfway through
      b4 = books[3]
      half_page = [(b4.page_count / 2.0).floor, 1].max
      ReadingProgress.create!(
        app_user: user,
        book: b4,
        last_page_number: half_page,
        total_words_read: (b4.word_count / 2.0).floor,
        total_duration_seconds: 900,
        session_count: 4,
        completed: false,
        last_read_at: 5.hours.ago
      )
      puts "  [halfway] #{b4.name} - page #{half_page}/#{b4.page_count}"

      # 5. Another completed book
      b5 = books[4]
      ReadingProgress.create!(
        app_user: user,
        book: b5,
        last_page_number: b5.page_count,
        total_words_read: b5.word_count,
        total_duration_seconds: 2400,
        session_count: 8,
        completed: true,
        completed_at: 2.days.ago,
        last_read_at: 2.days.ago
      )
      puts "  [completed] #{b5.name} - page #{b5.page_count}/#{b5.page_count}"

      puts ""
      puts "=== Summary ==="
      puts "Total reading progresses: #{user.reading_progresses.count}"
      puts "Completed: #{user.reading_progresses.completed.count}"
      puts "In progress: #{user.reading_progresses.in_progress.count}"
      puts "Done!"
    end
  end
end
