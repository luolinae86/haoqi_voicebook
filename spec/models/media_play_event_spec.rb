# frozen_string_literal: true

# == Schema Information
#
# Table name: media_play_events
#
#  id                                                          :bigint           not null, primary key
#  event_type(play_start/play_resume/play_pause/play_complete) :string(16)       not null
#  is_valid_play(是否有效播放（>=10秒）)                       :boolean          default(FALSE)
#  media_type(audio/video)                                     :string(8)        not null
#  play_seconds(本次播放时长)                                  :integer          default(0)
#  stat_date(日期 YYYY-MM-DD)                                  :string(255)      not null
#  total_duration(章节总时长)                                  :integer          default(0)
#  created_at                                                  :datetime         not null
#  app_user_id(用户ID)                                         :bigint           not null
#  book_id(图书ID)                                             :bigint           not null
#  chapter_id(章节ID)                                          :bigint           not null
#
# Indexes
#
#  idx_on_media_type_event_type_stat_date_516ccc8787     (media_type,event_type,stat_date)
#  index_media_play_events_on_app_user_id_and_stat_date  (app_user_id,stat_date)
#  index_media_play_events_on_book_id_and_stat_date      (book_id,stat_date)
#  index_media_play_events_on_chapter_id                 (chapter_id)
#
require 'rails_helper'

RSpec.describe MediaPlayEvent, type: :model do
  let(:user) { create(:app_user) }
  let(:book) { create(:book) }
  let(:chapter) { create(:chapter, book: book, duration: 600) }

  describe 'creation' do
    it 'creates a play_start event' do
      event = described_class.create!(
        app_user: user,
        book: book,
        chapter: chapter,
        media_type: 'audio',
        event_type: 'play_start',
        play_seconds: 0,
        total_duration: 600,
        stat_date: Time.zone.today.to_s
      )

      expect(event.is_valid_play).to be false
    end

    it 'marks as valid play when play_seconds >= 10' do
      event = described_class.create!(
        app_user: user,
        book: book,
        chapter: chapter,
        media_type: 'audio',
        event_type: 'play_complete',
        play_seconds: 480,
        total_duration: 600,
        is_valid_play: true,
        stat_date: Time.zone.today.to_s
      )

      expect(event.is_valid_play).to be true
    end
  end

  describe 'scopes' do
    it 'filters valid plays' do
      described_class.create!(app_user: user, book: book, chapter: chapter, media_type: 'audio', event_type: 'play_start', is_valid_play: false, stat_date: Time.zone.today.to_s)
      described_class.create!(app_user: user, book: book, chapter: chapter, media_type: 'audio', event_type: 'play_complete', is_valid_play: true, stat_date: Time.zone.today.to_s)
      expect(described_class.valid_plays.size).to eq(1)
    end

    it 'filters completed plays' do
      described_class.create!(app_user: user, book: book, chapter: chapter, media_type: 'audio', event_type: 'play_start', is_valid_play: false, stat_date: Time.zone.today.to_s)
      described_class.create!(app_user: user, book: book, chapter: chapter, media_type: 'audio', event_type: 'play_complete', is_valid_play: true, stat_date: Time.zone.today.to_s)
      expect(described_class.completed_plays.size).to eq(1)
    end

    it 'filters by media type' do
      described_class.create!(app_user: user, book: book, chapter: chapter, media_type: 'audio', event_type: 'play_start', is_valid_play: false, stat_date: Time.zone.today.to_s)
      described_class.create!(app_user: user, book: book, chapter: chapter, media_type: 'video', event_type: 'play_start', is_valid_play: false, stat_date: Time.zone.today.to_s)
      expect(described_class.by_media_type('audio').size).to eq(1)
    end
  end
end
