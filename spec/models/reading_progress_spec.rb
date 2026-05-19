# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_progress
#
#  app_user_id            :bigint           not null, comment: '用户ID'
#  book_id                :bigint           not null, comment: '图书ID'
#  last_page_number       :integer          not null, default(1), comment: '最新阅读到的页码'
#  total_words_read       :integer          not null, default(0), comment: '本书累计阅读字数'
#  total_duration_seconds :integer          not null, default(0), comment: '本书累计阅读时长(秒)'
#  session_count          :integer          not null, default(0), comment: '阅读次数'
#  completed              :boolean          not null, default(false), comment: '是否已读完'
#  completed_at           :datetime         comment: '完读时间'
#  last_read_at           :datetime         not null, comment: '最近阅读时间'
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
