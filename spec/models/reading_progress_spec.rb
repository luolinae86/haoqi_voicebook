# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_progress(阅读进度表)
#
#  id                                           :bigint           not null, primary key
#  completed(是否已读完)                        :boolean          default(FALSE), not null
#  completed_at(完读时间)                       :datetime
#  last_page_number(最新阅读到的页码)           :integer          default(1), not null
#  last_read_at(最近阅读时间)                   :datetime         not null
#  session_count(阅读次数)                      :integer          default(0), not null
#  total_duration_seconds(本书累计阅读时长(秒)) :integer          default(0), not null
#  total_words_read(本书累计阅读字数)           :integer          default(0), not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  app_user_id(用户ID)                          :bigint           not null
#  book_id(图书ID)                              :bigint           not null
#
# Indexes
#
#  index_reading_progress_on_app_user_id_and_book_id  (app_user_id,book_id) UNIQUE
#  index_reading_progress_on_book_id                  (book_id)
#
require 'rails_helper'

RSpec.describe ReadingProgress, type: :model do
  describe 'associations' do
    it 'belongs to app_user' do
      expect(ReadingProgress.reflect_on_association(:app_user)).to be_present
    end

    it 'belongs to book' do
      expect(ReadingProgress.reflect_on_association(:book)).to be_present
    end
  end

  describe 'scopes' do
    it 'returns recently read first' do
      book1 = create(:book)
      book2 = create(:book)
      user = create(:app_user)
      create(:reading_progress, app_user: user, book: book1, last_read_at: 2.days.ago)
      create(:reading_progress, app_user: user, book: book2, last_read_at: 1.hour.ago)

      expect(user.reading_progresses.recently_read.first.book).to eq(book2)
    end

    it 'filters completed books' do
      user = create(:app_user)
      completed = create(:reading_progress, app_user: user, completed: true)
      create(:reading_progress, app_user: user, completed: false)

      expect(user.reading_progresses.completed).to include(completed)
    end
  end
end
