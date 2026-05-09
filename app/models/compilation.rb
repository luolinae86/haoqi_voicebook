# frozen_string_literal: true

class Compilation < ApplicationRecord
  has_and_belongs_to_many :grades, join_table: :compilation_grades
  has_and_belongs_to_many :categories, join_table: :compilation_categories
  has_and_belongs_to_many :books, join_table: :compilation_books
  has_many :contents

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :editor_recommendation, length: { maximum: 15 }, allow_blank: true

  def tags_array
    tags || []
  end

  # 封面完整性检查
  def covers_complete?
    landscape_cover_url.present? && portrait_cover_url.present? && square_cover_url.present?
  end

  # 获取主封面
  def main_cover_url
    landscape_cover_url || banner_image_url
  end

  def self.cover_specifications
    {
      banner: { width: 1500, height: 932, max_size: 500, unit: 'KB', desc: '合辑banner' },
      landscape: { width: 1125, height: 540, max_size: 500, unit: 'KB', desc: '横图封面' },
      portrait: { width: 600, height: 768, max_size: 300, unit: 'KB', desc: '长方形封面' },
      square: { width: 600, height: 600, max_size: 300, unit: 'KB', desc: '正方形封面' }
    }
  end

  def self.ransackable_attributes(auth_object = nil)
    ["author", "created_at", "description", "editor_recommendation", "id", "intro_image_name", "intro_image_url", "landscape_cover_name", "landscape_cover_url", "name", "portrait_cover_name", "portrait_cover_url", "publisher", "square_cover_name", "square_cover_url", "tags", "total_count", "updated_at"]
  end
end
