# frozen_string_literal: true

# 图书模型
# 管理所有类型的内容：电子书、有声书、视频、绘本
class Book < ApplicationRecord
  # 内容类型枚举
  enum :content_type, { ebook: 0, audio: 1, video: 2, picture_book: 3 }, default: :ebook

  # 状态枚举
  enum :status, { draft: 0, published: 1, offline: 2 }, default: :draft

  # 电子书导入状态
  enum :import_status, { not_imported: 0, processing: 1, ready: 2, failed: 3 }, default: :not_imported

  # 关联关系
  belongs_to :category, optional: true               # 所属分类
  belongs_to :grade, optional: true                   # 适用年级
  has_many :chapters, dependent: :destroy              # 章节列表
  has_many :ebook_pages, -> { order(page_number: :asc) }, dependent: :destroy # 电子书页面
  has_one :audio_album, dependent: :destroy            # 有声专辑
  has_many :collection_items, dependent: :destroy      # 合集关联
  has_many :collections, through: :collection_items    # 所属合集
  has_many :bookshelves, dependent: :destroy            # 书架关联
  has_many :reading_records, dependent: :destroy        # 阅读记录
  has_many :bookmarks, dependent: :destroy              # 书签
  has_many :ranking_items, dependent: :destroy          # 排行关联
  has_many :recommendation_items, dependent: :destroy   # 推荐关联
  has_many :blacklisted_books, dependent: :destroy      # 黑名单关联

  # 验证规则
  validates :title, presence: true                     # 书名必填
  validates :content_type, presence: true               # 内容类型必填
  validates :play_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :word_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :page_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 }, allow_nil: true

  # 作用域
  scope :published_books, -> { where(status: :published) }
  scope :free_books, -> { where(is_free: true) }
  scope :vip_books, -> { where(is_vip: true) }
  scope :by_type, ->(type) { where(content_type: type) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :by_grade, ->(grade_id) { where(grade_id: grade_id) }
  scope :popular, -> { order(play_count: :desc) }
  scope :highest_rated, -> { order(rating: :desc) }
  scope :recently_added, -> { order(created_at: :desc) }
end
