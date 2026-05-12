# frozen_string_literal: true

# == Schema Information
#
# Table name: compilations
#
#  id                                                      :bigint           not null, primary key
#  author(作者)                                            :string(255)
#  banner_image_name(合辑banner图片文件名)                 :string(255)
#  banner_image_url(合辑banner图片URL (1500x932, <=500KB)) :string(255)
#  content_description(合辑简介（富文本/Markdown）)        :text(65535)
#  description(内容简介)                                   :text(65535)
#  editor_recommendation(编辑推荐语（15字以内）)           :string(15)
#  intro_image_name(图片简介文件名)                        :string(255)
#  intro_image_url(图片简介URL)                            :string(255)
#  landscape_cover_name(横图封面文件名)                    :string(255)
#  landscape_cover_url(横图封面URL (1125x540, <=500KB))    :string(255)
#  name(合辑名称)                                          :string(255)      not null
#  portrait_cover_name                                     :string(255)
#  portrait_cover_url                                      :string(255)
#  publisher(出版社)                                       :string(255)
#  square_cover_name                                       :string(255)
#  square_cover_url                                        :string(255)
#  tags(内容标签)                                          :string(255)
#  total_count(合辑总集数)                                 :integer          default(0)
#  created_at                                              :datetime         not null
#  updated_at                                              :datetime         not null
#
# Indexes
#
#  index_compilations_on_name  (name) UNIQUE
#
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
