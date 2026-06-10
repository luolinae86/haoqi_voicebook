# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_sessions(阅读记录表)
#
#  id                                 :bigint           not null, primary key
#  duration_seconds(本次阅读时长(秒)) :integer          default(0), not null
#  ended_at(结束阅读时间)             :datetime
#  page_number(阅读到的页码)          :integer          default(1), not null
#  read_date(阅读日期 YYYY-MM-DD)     :string(255)      not null
#  started_at(开始阅读时间)           :datetime         not null
#  word_count(本次阅读字数)           :integer          default(0), not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  app_user_id(用户ID)                :bigint           not null
#  book_id(图书ID)                    :bigint           not null
#
# Indexes
#
#  index_reading_sessions_on_app_user_id_and_book_id    (app_user_id,book_id)
#  index_reading_sessions_on_app_user_id_and_read_date  (app_user_id,read_date)
#  index_reading_sessions_on_book_id                    (book_id)
#
require 'rails_helper'

RSpec.describe ReadingSession, type: :model do
  describe 'associations' do
    it 'belongs to app_user' do
      expect(ReadingSession.reflect_on_association(:app_user)).to be_present
    end

    it 'belongs to book' do
      expect(ReadingSession.reflect_on_association(:book)).to be_present
    end
  end

  describe 'scopes' do
    it 'filters by date' do
      today = create(:reading_session, read_date: '2026-05-19')
      create(:reading_session, read_date: '2026-05-18')

      expect(ReadingSession.by_date('2026-05-19')).to include(today)
    end

    it 'returns recent sessions first' do
      old = create(:reading_session, started_at: 2.days.ago)
      new_session = create(:reading_session, started_at: 1.hour.ago)

      expect(ReadingSession.recent.first).to eq(new_session)
    end

    it 'filters by book and date' do
      book = create(:book)
      user = create(:app_user)
      today = Date.today.to_s
      session = create(:reading_session, app_user: user, book: book, read_date: today)
      create(:reading_session, app_user: user, book: create(:book), read_date: today)
      create(:reading_session, app_user: user, book: book, read_date: '2025-01-01')

      expect(ReadingSession.by_book_and_date(book, today)).to include(session)
      expect(ReadingSession.by_book_and_date(book, today).size).to eq(1)
    end
  end
end
