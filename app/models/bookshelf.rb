# == Schema Information
#
# Table name: bookshelves(书架表)
#
#  id                                   :bigint           not null, primary key
#  last_read_at(最后阅读时间)           :datetime
#  reading_progress(阅读进度(%))        :decimal(5, 2)    default(0.0)
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  app_user_id(用户ID)                  :integer          not null
#  book_id(图书ID)                      :bigint           not null
#  last_read_chapter_id(最后阅读章节ID) :bigint
#
# Indexes
#
#  index_bookshelves_on_app_user_id              (app_user_id)
#  index_bookshelves_on_app_user_id_and_book_id  (app_user_id,book_id) UNIQUE
#  index_bookshelves_on_book_id                  (book_id)
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
