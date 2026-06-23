# frozen_string_literal: true

class CreateDailyStatsTables < ActiveRecord::Migration[8.0]
  def change
    # 用户阅读日统计表（web 直接查询用）
    return if table_exists?(:daily_reading_stats)

    create_table :daily_reading_stats do |t|
      t.bigint :app_user_id, null: false, comment: "用户ID"
      t.string :stat_date, null: false, comment: "统计日期 YYYY-MM-DD"
      t.integer :session_count, default: 0, comment: "当日阅读次数"
      t.integer :total_duration_seconds, default: 0, comment: "当日总阅读时长(秒)"
      t.integer :books_read_count, default: 0, comment: "当日阅读书籍数"
      t.integer :avg_duration_seconds, default: 0, comment: "平均每次阅读时长(秒)"
      t.integer :completed_books_count, default: 0, comment: "当日完读书籍数"
      t.float :completion_rate, default: 0.0, comment: "完读率"
      t.integer :consecutive_days, default: 0, comment: "截至当日连续阅读天数"
      t.timestamps
    end

    add_index :daily_reading_stats, [:app_user_id, :stat_date], unique: true
    add_index :daily_reading_stats, :stat_date

    # 内容日统计表（web 直接查询用）
    create_table :daily_content_stats do |t|
      t.string :stat_date, null: false, comment: "统计日期 YYYY-MM-DD"
      t.bigint :book_id, comment: "图书ID（NULL=全平台汇总）"
      t.string :content_type, comment: "内容类型（ebook/audio/video/picture_book）"
      t.integer :clicks_count, default: 0, comment: "点击量"
      t.integer :reads_count, default: 0, comment: "阅读量（停留≥30秒）"
      t.integer :valid_plays_count, default: 0, comment: "有效播放量（≥10秒）"
      t.integer :completed_plays_count, default: 0, comment: "完播次数"
      t.integer :read_users_count, default: 0, comment: "阅读人数（去重）"
      t.integer :play_users_count, default: 0, comment: "播放人数（去重）"
      t.integer :completed_users_count, default: 0, comment: "完读人数（去重）"
      t.float :completion_rate, default: 0.0, comment: "完读率"
      t.timestamps
    end

    add_index :daily_content_stats, [:stat_date, :book_id]
    add_index :daily_content_stats, :stat_date

    # 渠道日统计表（web 直接查询用）
    create_table :daily_channel_stats do |t|
      t.string :stat_date, null: false, comment: "统计日期 YYYY-MM-DD"
      t.string :channel, limit: 32, comment: "渠道（NULL=全部）"
      t.integer :registrations, default: 0, comment: "当日注册量"
      t.integer :active_users, default: 0, comment: "当日活跃用户数"
      t.integer :paid_users, default: 0, comment: "当日付费用户数"
      t.decimal :paid_amount, precision: 10, scale: 2, default: 0, comment: "当日付费金额"
      t.float :conversion_rate, default: 0.0, comment: "付费转化率"
      t.decimal :cac, precision: 10, scale: 2, default: 0, comment: "获客成本"
      t.timestamps
    end

    add_index :daily_channel_stats, [:stat_date, :channel], unique: true
    add_index :daily_channel_stats, :stat_date
  end
end
