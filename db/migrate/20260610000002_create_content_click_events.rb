# frozen_string_literal: true

# 内容点击事件表 — 记录用户对内容的点击/阅读行为，用于内容消费分析
class CreateContentClickEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :content_click_events do |t|
      t.bigint :app_user_id, null: false, comment: '用户ID'
      t.bigint :book_id, comment: '图书ID'
      t.bigint :chapter_id, comment: '章节ID（有声/视频专用）'
      t.string :content_type, limit: 16, null: false, default: 'book', comment: '类型：book/chapter'
      t.string :click_type, limit: 32, null: false, comment: 'click/read/play_start'
      t.integer :duration_seconds, default: 0, comment: '本次停留/播放时长'
      t.string :stat_date, null: false, comment: '日期 YYYY-MM-DD'
      t.datetime :created_at, null: false

      t.index %i[app_user_id stat_date]
      t.index %i[book_id stat_date]
      t.index %i[content_type click_type stat_date]
    end
  end
end
