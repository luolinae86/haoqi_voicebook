# frozen_string_literal: true

# 书签模型
# 管理用户在阅读中添加的书签
class Bookmark < ApplicationRecord
  # 关联关系
  belongs_to :app_user, class_name: "AppUser"    # 所属用户
  belongs_to :book     # 关联图书
  belongs_to :chapter, optional: true  # 关联章节

  # 验证规则
  validates :position, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 作用域
  scope :recent, -> { order(created_at: :desc) }
end
