# frozen_string_literal: true

# 有声/视频播放事件模型 — 记录音频/视频播放行为
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
