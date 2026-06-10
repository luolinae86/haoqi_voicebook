# frozen_string_literal: true

# == Schema Information
#
# Table name: content_click_events
#
#  id                                  :bigint           not null, primary key
#  click_type(click/read/play_start)   :string(32)       not null
#  content_type(类型：book/chapter)    :string(16)       default("book"), not null
#  duration_seconds(本次停留/播放时长) :integer          default(0)
#  stat_date(日期 YYYY-MM-DD)          :string(255)      not null
#  created_at                          :datetime         not null
#  app_user_id(用户ID)                 :bigint           not null
#  book_id(图书ID)                     :bigint
#  chapter_id(章节ID（有声/视频专用）) :bigint
#
# Indexes
#
#  idx_on_content_type_click_type_stat_date_3cca833442      (content_type,click_type,stat_date)
#  index_content_click_events_on_app_user_id_and_stat_date  (app_user_id,stat_date)
#  index_content_click_events_on_book_id_and_stat_date      (book_id,stat_date)
#
require 'rails_helper'

RSpec.describe ContentClickEvent, type: :model do
  let(:user) { create(:app_user) }
  let(:book) { create(:book) }

  describe 'creation' do
    it 'creates a click event for a book' do
      event = described_class.create!(
        app_user: user,
        book: book,
        content_type: 'book',
        click_type: 'click',
        stat_date: Time.zone.today.to_s
      )

      expect(event.app_user_id).to eq(user.id)
      expect(event.book_id).to eq(book.id)
      expect(event.chapter_id).to be_nil
    end

    it 'creates a read event with duration' do
      event = described_class.create!(
        app_user: user,
        book: book,
        content_type: 'book',
        click_type: 'read',
        duration_seconds: 120,
        stat_date: Time.zone.today.to_s
      )

      expect(event.duration_seconds).to eq(120)
    end
  end

  describe 'scopes' do
    it 'filters by date' do
      event = described_class.create!(
        app_user: user,
        book: book,
        content_type: 'book',
        click_type: 'click',
        stat_date: Time.zone.today.to_s
      )
      expect(described_class.by_date(Time.zone.today)).to include(event)
    end

    it 'filters by book' do
      book2 = create(:book)
      described_class.create!(app_user: user, book: book, content_type: 'book', click_type: 'click', stat_date: Time.zone.today.to_s)
      described_class.create!(app_user: user, book: book2, content_type: 'book', click_type: 'click', stat_date: Time.zone.today.to_s)
      expect(described_class.by_book(book.id).size).to eq(1)
    end

    it 'filters by click type' do
      described_class.create!(app_user: user, book: book, content_type: 'book', click_type: 'click', stat_date: Time.zone.today.to_s)
      described_class.create!(app_user: user, book: book, content_type: 'book', click_type: 'read', stat_date: Time.zone.today.to_s)
      expect(described_class.by_click_type('click').size).to eq(1)
    end
  end
end
