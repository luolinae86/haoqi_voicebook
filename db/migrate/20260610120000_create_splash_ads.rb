# frozen_string_literal: true

# 创建开屏广告表
class CreateSplashAds < ActiveRecord::Migration[8.0]
  def change
    create_table :splash_ads do |t|
      t.string :image_url, null: false, comment: '图片URL'
      t.string :link_type, null: false, comment: '链接类型: single_book/category'
      t.bigint :book_id, comment: '关联图书ID'
      t.bigint :category_id, comment: '关联分类ID'
      t.string :push_scope, default: 'all_users', null: false, comment: '推送范围: all_users/age_range/specific_users'
      t.integer :min_age, comment: '最小年龄'
      t.integer :max_age, comment: '最大年龄'
      t.json :user_group, comment: '指定用户群体'
      t.string :push_mode, default: 'immediate', null: false, comment: '推送方式: immediate/first_open_daily'
      t.datetime :scheduled_at, comment: '定时推送时间'
      t.string :status, default: 'draft', null: false, comment: '状态: draft/active/expired/disabled'
      t.datetime :start_time, null: false, comment: '开始时间'
      t.datetime :end_time, null: false, comment: '结束时间'
      t.integer :send_count, default: 0, comment: '发送数'
      t.integer :click_count, default: 0, comment: '点击数'
      t.decimal :delivery_rate, precision: 5, scale: 4, default: '0.0', comment: '送达率'
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :splash_ads, :book_id
    add_index :splash_ads, :category_id
    add_index :splash_ads, :deleted_at
  end
end
