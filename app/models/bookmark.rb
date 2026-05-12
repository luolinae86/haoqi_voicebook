# == Schema Information
#
# Table name: bookmarks
#
#  id                  :bigint           not null, primary key
#  position(位置(%))   :decimal(5, 2)    default(0.0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  app_user_id(用户ID) :integer          not null
#  book_id(图书ID)     :integer          not null
#  chapter_id(章节ID)  :integer
#
# Indexes
#
#  index_bookmarks_on_app_user_id  (app_user_id)
#  index_bookmarks_on_book_id      (book_id)
#
# frozen_string_literal: true

# 书签模型
# 管理用户在阅读中添加的书签
class Bookmark < ApplicationRecord
  # 关联关系
  belongs_to :app_user, class_name: "AppUser" # 所属用户
  belongs_to :book # 关联图书

  # 验证规则
  validates :position, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 作用域
  scope :recent, -> { order(created_at: :desc) }
end
