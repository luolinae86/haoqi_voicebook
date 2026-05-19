# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_sessions
#
#  app_user_id      :bigint           not null, comment: '用户ID'
#  book_id          :bigint           not null, comment: '图书ID'
#  page_number      :integer          not null, default(1), comment: '阅读到的页码'
#  word_count       :integer          not null, default(0), comment: '本次阅读字数'
#  duration_seconds :integer          not null, default(0), comment: '本次阅读时长(秒)'
#  started_at       :datetime         not null, comment: '开始阅读时间'
#  ended_at         :datetime         comment: '结束阅读时间'
#  read_date        :string           not null, comment: '阅读日期 YYYY-MM-DD'
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
  end
end
