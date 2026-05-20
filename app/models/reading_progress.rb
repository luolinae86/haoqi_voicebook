# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_progress
#
#  app_user_id           :bigint           not null, comment: '用户ID'
#  book_id               :bigint           not null, comment: '图书ID'
#  last_page_number      :integer          not null, default(1), comment: '最新阅读到的页码'
#  total_words_read      :integer          not null, default(0), comment: '本书累计阅读字数'
#  total_duration_seconds:integer          not null, default(0), comment: '本书累计阅读时长(秒)'
#  session_count         :integer          not null, default(0), comment: '阅读次数'
#  completed             :boolean          not null, default(false), comment: '是否已读完'
#  completed_at          :datetime         comment: '完读时间'
#  last_read_at          :datetime         not null, comment: '最近阅读时间'
#
class ReadingProgress < ApplicationRecord
  self.table_name = 'reading_progress'
  belongs_to :app_user
  belongs_to :book

  scope :recently_read, -> { order(last_read_at: :desc) }
  scope :completed, -> { where(completed: true) }
  scope :in_progress, -> { where(completed: false) }
  scope :recently_completed, ->(app_user_id, since:) { where(app_user_id: app_user_id, completed: true).where('completed_at >= ?', since) }
end
