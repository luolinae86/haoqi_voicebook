# frozen_string_literal: true

# 内容点击事件模型 — 记录用户对内容的点击/阅读/播放行为
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
class ContentClickEvent < ApplicationRecord
  belongs_to :app_user
  belongs_to :book, optional: true
  belongs_to :chapter, optional: true

  scope :by_date, ->(date) { where(stat_date: date.to_s) }
  scope :by_date_range, ->(start_date, end_date) { where(stat_date: start_date.to_s..end_date.to_s) }
  scope :by_book, ->(book_id) { where(book_id: book_id) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :by_click_type, ->(type) { where(click_type: type) }
end
