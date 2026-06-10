# frozen_string_literal: true

# == Schema Information
#
# Table name: splash_ads
#
#  id                                                       :bigint           not null, primary key
#  click_count(点击数)                                      :integer          default(0)
#  deleted_at                                               :datetime
#  delivery_rate(送达率)                                    :decimal(5, 4)    default(0.0)
#  end_time(结束时间)                                       :datetime         not null
#  grade_ids(按年级推送时的目标年级ID列表)                   :json
#  image_url(图片URL)                                       :string(255)      not null
#  link_type(链接类型: single_book/category)                :string(255)      not null
#  max_age(最大年龄)                                        :integer
#  min_age(最小年龄)                                        :integer
#  push_mode(推送方式: immediate/first_open_daily)          :string(255)      default("immediate"), not null
#  push_scope(推送范围: all_users/age_range/specific_users) :string(255)      default("all_users"), not null
#  scheduled_at(定时推送时间)                               :datetime
#  send_count(发送数)                                       :integer          default(0)
#  start_time(开始时间)                                     :datetime         not null
#  status(状态: draft/active/expired/disabled)              :string(255)      default("draft"), not null
#  user_group(指定用户群体)                                 :json
#  created_at                                               :datetime         not null
#  updated_at                                               :datetime         not null
#  book_id(关联图书ID)                                      :bigint
#  category_id(关联分类ID)                                  :bigint
#
# Indexes
#
#  index_splash_ads_on_book_id      (book_id)
#  index_splash_ads_on_category_id  (category_id)
#  index_splash_ads_on_deleted_at   (deleted_at)
#
class SplashAd < ApplicationRecord
  belongs_to :book, optional: true
  belongs_to :category, optional: true

  # 链接类型
  LINK_TYPES = {
    single_book: '单本图书',
    category: '图书分类'
  }.freeze

  PUSH_SCOPES = {
    all_users: '所有用户',
    age_range: '按年龄段',
    specific_users: '指定用户'
  }.freeze

  PUSH_MODES = {
    immediate: '定时推送',
    first_open_daily: '首次打开APP推送'
  }.freeze

  STATUSES = {
    draft: '草稿',
    active: '投放中',
    expired: '已过期',
    disabled: '已停用'
  }.freeze

  enum :link_type, {
    single_book: 'single_book',
    category: 'category'
  }, prefix: true

  enum :push_scope, {
    all_users: 'all_users',
    age_range: 'age_range',
    specific_users: 'specific_users'
  }, prefix: true

  enum :push_mode, {
    immediate: 'immediate',
    first_open_daily: 'first_open_daily'
  }, prefix: true

  enum :status, {
    draft: 'draft',
    active: 'active',
    expired: 'expired',
    disabled: 'disabled'
  }, prefix: true

  validates :image_url, presence: true
  validates :link_type, presence: true
  validates :push_scope, presence: true
  validates :push_mode, presence: true

  validate :link_type_consistency

  validates :min_age, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 18, allow_nil: true }
  validates :max_age, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 18, allow_nil: true }
  validate :age_range_validity

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_link_type, ->(link_type) { where(link_type: link_type) if link_type.present? }
  scope :by_push_scope, ->(push_scope) { where(push_scope: push_scope) if push_scope.present? }
  scope :active_now, -> { where(status: :active) }
  scope :ordered, -> { order(created_at: :desc) }

  # 根据用户年级匹配广告
  # push_scope = all_users: 所有用户可见
  # push_scope = age_range: 仅 grade_ids 中包含用户 grade_id 的可见；grade_ids 为空时降级为所有用户可见
  scope :for_user_grade, lambda { |grade_id|
    if grade_id.present?
      where(<<~SQL.squish, grade_id: grade_id)
        push_scope = 'all_users'
        OR (push_scope = 'age_range' AND (grade_ids IS NULL OR JSON_LENGTH(grade_ids) = 0 OR JSON_CONTAINS(grade_ids, CAST(:grade_id AS JSON))))
      SQL
    else
      where("push_scope = 'all_users' OR (push_scope = 'age_range' AND (grade_ids IS NULL OR JSON_LENGTH(grade_ids) = 0))")
    end
  }

  def link_type_name
    LINK_TYPES[link_type.to_sym] || link_type
  end

  def push_scope_name
    PUSH_SCOPES[push_scope.to_sym] || push_scope
  end

  def push_mode_name
    PUSH_MODES[push_mode.to_sym] || push_mode
  end

  def status_name
    STATUSES[status.to_sym] || status
  end

  def age_range_display
    return nil unless push_scope == 'age_range'

    "#{min_age || 0} ~ #{max_age || 18} 岁"
  end

  def time_range_display
    "#{start_time&.strftime('%Y-%m-%d %H:%M')} ~ #{end_time&.strftime('%Y-%m-%d %H:%M')}"
  end

  def delivery_rate_display
    return '0%' if send_count.zero?

    "#{(delivery_rate * 100).round(2)}%"
  end

  def click_rate_display
    return '0%' if send_count.zero?

    "#{((click_count.to_f / send_count) * 100).round(2)}%"
  end

  private

  def link_type_consistency
    case link_type
    when 'single_book'
      errors.add(:book_id, '不能为空') if book_id.blank?
    when 'category'
      errors.add(:category_id, '不能为空') if category_id.blank?
    end
  end

  def age_range_validity
    return unless push_scope == 'age_range'

    if min_age.blank? || max_age.blank?
      errors.add(:base, '指定年龄段时，最小年龄和最大年龄都必须填写')
    elsif min_age > max_age
      errors.add(:min_age, '不能大于最大年龄')
    end
  end
end
