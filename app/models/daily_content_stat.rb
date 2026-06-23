# frozen_string_literal: true

# == Schema Information
#
# Table name: daily_content_stats
#
class DailyContentStat < ApplicationRecord
  belongs_to :book, optional: true

  scope :by_date, ->(date) { where(stat_date: date) }
  scope :by_book, ->(book_id) { where(book_id: book_id) }
  scope :platform_summary, -> { where(book_id: nil) }
end
