# frozen_string_literal: true

# 书架模型
# 管理用户的个人书架，记录阅读进度
class Bookshelf < ApplicationRecord
  # 关联关系
  belongs_to :user    # 所属用户
  belongs_to :book    # 关联图书
  belongs_to :last_read_chapter, class_name: "Chapter", optional: true  # 最后阅读章节

  # 验证规则
  validates :user_id, uniqueness: { scope: :book_id, message: "该图书已在书架中" }
  validates :reading_progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # 作用域
  scope :recently_read, -> { order(last_read_at: :desc) }

  # 更新阅读进度
  def update_progress!(progress:, chapter: nil)
    attrs = { reading_progress: progress, last_read_at: Time.current }
    attrs[:last_read_chapter_id] = chapter.id if chapter
    update!(attrs)
  end
end
