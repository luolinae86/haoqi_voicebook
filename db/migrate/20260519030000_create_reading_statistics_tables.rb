class CreateReadingStatisticsTables < ActiveRecord::Migration[8.0]
  def change
    create_table :reading_sessions, comment: '阅读记录表' do |t|
      t.bigint :app_user_id, null: false, comment: '用户ID'
      t.bigint :book_id, null: false, comment: '图书ID'
      t.integer :page_number, null: false, default: 1, comment: '阅读到的页码'
      t.integer :word_count, null: false, default: 0, comment: '本次阅读字数'
      t.integer :duration_seconds, null: false, default: 0, comment: '本次阅读时长(秒)'
      t.datetime :started_at, null: false, comment: '开始阅读时间'
      t.datetime :ended_at, comment: '结束阅读时间'
      t.string :read_date, null: false, comment: '阅读日期 YYYY-MM-DD'
      t.timestamps
    end
    add_index :reading_sessions, [:app_user_id, :book_id]
    add_index :reading_sessions, [:app_user_id, :read_date]
    add_index :reading_sessions, [:book_id]

    create_table :reading_progress, comment: '阅读进度表' do |t|
      t.bigint :app_user_id, null: false, comment: '用户ID'
      t.bigint :book_id, null: false, comment: '图书ID'
      t.integer :last_page_number, null: false, default: 1, comment: '最新阅读到的页码'
      t.integer :total_words_read, null: false, default: 0, comment: '本书累计阅读字数'
      t.integer :total_duration_seconds, null: false, default: 0, comment: '本书累计阅读时长(秒)'
      t.integer :session_count, null: false, default: 0, comment: '阅读次数'
      t.boolean :completed, null: false, default: false, comment: '是否已读完'
      t.datetime :completed_at, comment: '完读时间'
      t.datetime :last_read_at, null: false, comment: '最近阅读时间'
      t.timestamps
    end
    add_index :reading_progress, [:app_user_id, :book_id], unique: true
    add_index :reading_progress, [:book_id]

    create_table :user_reading_daily_stats, comment: '用户阅读日统计表' do |t|
      t.bigint :app_user_id, null: false, comment: '用户ID'
      t.string :stat_date, null: false, comment: '统计日期 YYYY-MM-DD'
      t.integer :session_count, null: false, default: 0, comment: '当日阅读次数'
      t.integer :total_duration_seconds, null: false, default: 0, comment: '当日总阅读时长(秒)'
      t.integer :total_words_read, null: false, default: 0, comment: '当日总阅读字数'
      t.integer :books_read_count, null: false, default: 0, comment: '当日阅读书籍数'
      t.timestamps
    end
    add_index :user_reading_daily_stats, [:app_user_id, :stat_date], unique: true

    create_table :book_stats, comment: '图书统计表' do |t|
      t.bigint :book_id, null: false, comment: '图书ID'
      t.integer :total_readers, null: false, default: 0, comment: '总阅读人数(去重)'
      t.integer :total_reads, null: false, default: 0, comment: '总阅读次数'
      t.integer :total_duration_seconds, null: false, default: 0, comment: '总阅读时长(秒)'
      t.integer :total_words_read, null: false, default: 0, comment: '总阅读字数'
      t.integer :completed_count, null: false, default: 0, comment: '完读人数'
      t.float :completion_rate, null: false, default: 0.0, comment: '完读率'
      t.integer :weekly_readers, null: false, default: 0, comment: '近7天阅读人数'
      t.integer :weekly_reads, null: false, default: 0, comment: '近7天阅读次数'
      t.integer :monthly_readers, null: false, default: 0, comment: '近30天阅读人数'
      t.integer :monthly_reads, null: false, default: 0, comment: '近30天阅读次数'
      t.timestamps
    end
    add_index :book_stats, :book_id, unique: true
    add_index :book_stats, :weekly_readers
    add_index :book_stats, :monthly_readers

    create_table :leaderboards, comment: '排行榜表' do |t|
      t.string :name, null: false, comment: '榜单名称'
      t.string :slug, null: false, comment: '唯一标识'
      t.integer :ranking_type, null: false, default: 0, comment: '0-自动 1-手动'
      t.string :auto_rule, comment: '自动规则'
      t.string :category_filter, comment: '按分类过滤'
      t.integer :limit_count, default: 50, comment: '最多展示数量'
      t.boolean :is_active, null: false, default: true, comment: '是否启用'
      t.integer :sort_order, null: false, default: 0, comment: '展示排序'
      t.datetime :last_calculated_at, comment: '自动榜单最后计算时间'
      t.text :description, comment: '榜单描述'
      t.timestamps
    end
    add_index :leaderboards, :slug, unique: true
    add_index :leaderboards, [:ranking_type, :is_active]

    create_table :leaderboard_items, comment: '排行榜项表' do |t|
      t.bigint :leaderboard_id, null: false, comment: '排行榜ID'
      t.bigint :book_id, null: false, comment: '图书ID'
      t.integer :rank, null: false, comment: '排名'
      t.decimal :score, precision: 10, scale: 2, default: 0.0, comment: '得分'
      t.timestamps
    end
    add_index :leaderboard_items, :leaderboard_id
    add_index :leaderboard_items, [:leaderboard_id, :rank]
    add_index :leaderboard_items, [:leaderboard_id, :book_id], unique: true
  end
end
