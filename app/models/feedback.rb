# frozen_string_literal: true

# == Schema Information
#
# Table name: feedbacks
#
#  app_user_id  :integer          not null
#  content      :text(65535)      not null
#  feedback_type :integer         default(0), not null
#  images       :text(65535)
#  status       :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class Feedback < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :app_user, class_name: 'AppUser'

  enum :feedback_type, { bug: 0, content_suggestion: 1, other: 2 }
  enum :status, { pending: 0, processing: 1, resolved: 2 }

  TYPE_NAMES = {
    bug: '功能问题',
    content_suggestion: '内容建议',
    other: '其他'
  }.freeze

  STATUS_NAMES = {
    pending: '待处理',
    processing: '处理中',
    resolved: '已解决'
  }.freeze

  MAX_IMAGES = 3
  MAX_CONTENT_LENGTH = 500

  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }
  validate :images_count

  def type_name
    TYPE_NAMES[feedback_type.to_sym] || feedback_type
  end

  def status_name
    STATUS_NAMES[status.to_sym] || status
  end

  def images_array
    return [] if images.blank?
    JSON.parse(images) || []
  rescue JSON::ParserError
    []
  end

  private

  def images_count
    return if images.blank?
    arr = images_array
    errors.add(:images, "最多上传#{MAX_IMAGES}张图片") if arr.size > MAX_IMAGES
  end
end
