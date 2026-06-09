# frozen_string_literal: true

# 有声/视频播放事件表 — 记录音频/视频播放行为，用于播放量、完播率分析
class CreateMediaPlayEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :media_play_events do |t|
      t.bigint :app_user_id, null: false, comment: '用户ID'
      t.bigint :book_id, null: false, comment: '图书ID'
      t.bigint :chapter_id, null: false, comment: '章节ID'
      t.string :media_type, limit: 8, null: false, comment: 'audio/video'
      t.string :event_type, limit: 16, null: false, comment: 'play_start/play_resume/play_pause/play_complete'
      t.integer :play_seconds, default: 0, comment: '本次播放时长'
      t.integer :total_duration, default: 0, comment: '章节总时长'
      t.boolean :is_valid_play, default: false, comment: '是否有效播放（>=10秒）'
      t.string :stat_date, null: false, comment: '日期 YYYY-MM-DD'
      t.datetime :created_at, null: false

      t.index %i[app_user_id stat_date]
      t.index %i[book_id stat_date]
      t.index :chapter_id
      t.index %i[media_type event_type stat_date]
    end
  end
end
