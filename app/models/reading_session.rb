# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_sessions
#
#  app_user_id     :bigint           not null, comment: '用户ID'
#  book_id         :bigint           not null, comment: '图书ID'
#  page_number     :integer          not null, default(1), comment: '阅读到的页码'
#  word_count      :integer          not null, default(0), comment: '本次阅读字数'
#  duration_seconds:integer          not null, default(0), comment: '本次阅读时长(秒)'
#  started_at      :datetime         not null, comment: '开始阅读时间'
#  ended_at        :datetime         comment: '结束阅读时间'
#  read_date       :string           not null, comment: '阅读日期 YYYY-MM-DD'
#
class ReadingSession < ApplicationRecord
  belongs_to :app_user
  belongs_to :book

  scope :by_date, ->(date) { where(read_date: date) }
  scope :recent, -> { order(started_at: :desc) }
  scope :last_n_days, ->(days) { where(read_date: days.days.ago.to_date..Date.today) }
  scope :by_book_and_date, ->(book, date) { where(book: book, read_date: date) }
end
