# == Schema Information
#
# Table name: bookmarks
#
#   id                   integer(8)         not null, primary key
#   app_user_id          integer(4)         not null
#   book_id              integer(4)         not null
#   chapter_id           integer(4)         
#   position             decimal            default(0.00)
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_bookmarks_on_app_user_id on app_user_id
#  Index: index_bookmarks_on_book_id on book_id
#
#
# frozen_string_literal: true

# 书签模型
# 管理用户在阅读中添加的书签
class Bookmark < ApplicationRecord
  # 关联关系
  belongs_to :app_user, class_name: "AppUser" # 所属用户
  belongs_to :book # 关联图书
  belongs_to :chapter, optional: true # 关联章节

  # 验证规则
  validates :position, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 作用域
  scope :recent, -> { order(created_at: :desc) }
end
