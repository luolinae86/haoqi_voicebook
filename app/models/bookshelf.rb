# == Schema Information
#
# Table name: bookshelves
#
#   id                   integer(8)         not null, primary key
#   app_user_id          integer(4)         not null
#   book_id              integer(4)         not null
#   reading_progress     decimal            default(0.00)
#   last_read_chapter_id integer(4)
#   last_read_at         datetime
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_bookshelves_on_app_user_id_and_book_id on app_user_id, book_id (unique)
#  Index: index_bookshelves_on_app_user_id on app_user_id
#  Index: index_bookshelves_on_book_id on book_id
#
#
# frozen_string_literal: true

# 书架模型
# 管理用户的个人书架，记录阅读进度
class Bookshelf < ApplicationRecord
  # 关联关系
  belongs_to :app_user, class_name: "AppUser" # 所属用户
  belongs_to :book # 关联图书

  # 验证规则
  validates :app_user_id, uniqueness: { scope: :book_id, message: "该图书已在书架中" }
  validates :reading_progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # 作用域
  scope :recently_read, -> { order(last_read_at: :desc) }
end
