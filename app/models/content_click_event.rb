# frozen_string_literal: true

# 内容点击事件模型 — 记录用户对内容的点击/阅读/播放行为
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
