# == Schema Information
#
# Table name: reading_records
#
#   id                   integer(8)         not null, primary key
#   app_user_id          integer(4)         not null
#   book_id              integer(4)         not null
#   chapter_id           integer(4)         
#   words_read           integer(4)         not null, default(0)
#   duration_minutes     integer(4)         not null, default(0)
#   read_at              datetime           
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_reading_records_on_app_user_id on app_user_id
#  Index: index_reading_records_on_book_id on book_id
#  Index: index_reading_records_on_read_at on read_at
#
#
# frozen_string_literal: true

# 阅读记录模型
# 记录用户的详细阅读行为（阅读字数、时长等）
class ReadingRecord < ApplicationRecord
  # 关联关系
  belongs_to :app_user, class_name: "AppUser" # 所属用户
  belongs_to :book                       # 阅读的图书
  belongs_to :chapter, optional: true    # 阅读的章节

  # 验证规则
  validates :words_read, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_minutes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 作用域
  scope :today, -> { where(read_at: Time.current.all_day) }
  scope :this_week, -> { where(read_at: Time.current.all_week) }
  scope :this_month, -> { where(read_at: Time.current.all_month) }
end
