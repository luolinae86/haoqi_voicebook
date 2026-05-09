# frozen_string_literal: true

class Book < ApplicationRecord
  belongs_to :supplier, optional: true
  belongs_to :category, optional: true
  belongs_to :author, optional: true
  has_and_belongs_to_many :grades, join_table: :book_grades
  has_and_belongs_to_many :compilations, join_table: :compilation_books
  has_and_belongs_to_many :category_subs, join_table: :category_sub_books
  has_many :chapters
  has_many :contents

  # voicebook-specific associations
  has_many :bookshelves, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :blacklisted_books, dependent: :destroy
  has_many :ebook_pages, dependent: :destroy

  # 验证
  validates :name, presence: true, length: { maximum: 100 }

  # voicebook scopes
  enum :status, { draft: 0, published: 1, offline: 2 }
  enum :content_type, { ebook: 0, audio: 1, video: 2, picture_book: 3 }
  enum :import_status, { not_imported: 0, processing: 1, ready: 2, failed: 3 }, default: :not_imported
  enum :epub_export_status, { not_exported: 0, exporting: 1, completed: 2, export_failed: 3 }, default: :not_exported, prefix: true

  scope :published_books, -> { where(status: :published) }
  scope :by_type, ->(type) { where(content_type: type) }
  scope :by_category, ->(id) { where(category_id: id) }
  scope :by_grade, ->(id) { where(grade_id: id) }
  scope :free_books, -> { where(is_free: true) }
  scope :popular, -> { order(play_count: :desc) }
  scope :highest_rated, -> { order(rating: :desc) }
  scope :recently_added, -> { order(created_at: :desc) }

  def themes_array
    themes || []
  end

  private

  def self.ransackable_attributes(auth_object = nil)
    ["author", "id", "name", "supplier_id", "themes", "status", "content_type", "is_free", "is_vip", "category_id", "grade_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category", "chapters", "compilations", "grades", "supplier", "author", "ebook_pages"]
  end
end
