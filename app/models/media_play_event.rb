# frozen_string_literal: true

# 有声/视频播放事件模型 — 记录音频/视频播放行为
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
class MediaPlayEvent < ApplicationRecord
  belongs_to :app_user
  belongs_to :book
  belongs_to :chapter

  scope :by_date, ->(date) { where(stat_date: date.to_s) }
  scope :by_date_range, ->(start_date, end_date) { where(stat_date: start_date.to_s..end_date.to_s) }
  scope :by_book, ->(book_id) { where(book_id: book_id) }
  scope :by_media_type, ->(type) { where(media_type: type) }
  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :valid_plays, -> { where(is_valid_play: true) }
  scope :completed_plays, -> { where(event_type: 'play_complete') }
end
