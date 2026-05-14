# frozen_string_literal: true

# == Schema Information
#
# Table name: chapters
#
#  id                                                                   :bigint           not null, primary key
#  content_file_name(章节内容文件名)                                    :string(255)
#  content_file_type(内容文件类型 (epub/pdf/txt))                       :string(255)
#  content_file_url(章节内容文件URL)                                    :string(255)
#  cover_image_url(章节封面图片URL)                                     :string(255)
#  epub_export_error(EPUB 导出失败原因)                                 :text(65535)
#  epub_export_status(EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败) :integer          default("not_exported")
#  epub_oss_key(EPUB 文件 OSS 路径)                                     :string(255)
#  epub_oss_url(EPUB 文件公网 URL)                                      :string(255)
#  is_free(是否免费)                                                    :boolean          default(FALSE)
#  is_published(是否上线)                                               :boolean          default(FALSE)
#  name(章节名称)                                                       :string(255)      not null
#  nav_oss_url(nav.xhtml 的 OSS URL)                                    :string(255)
#  sn(排序)                                                             :integer          default(0)
#  styles_oss_url(book.css 的 OSS URL)                                  :string(255)
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  book_id(所属绘本)                                                    :bigint           not null
#
# Indexes
#
#  index_chapters_on_book_id  (book_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
class Chapter < ApplicationRecord
  belongs_to :book
  has_many :ebook_pages, dependent: :destroy

  enum :epub_export_status, { not_exported: 0, exporting: 1, completed: 2, export_failed: 3 }, default: :not_exported, prefix: true

  # 内容文件类型
  FILE_TYPES = {
    epub: 'epub',
    pdf: 'pdf',
    mp3: 'mp3',
    mp4: 'mp4'
  }.freeze

  FILE_TYPE_NAMES = {
    epub: 'EPUB电子书',
    pdf: 'PDF文档',
    mp3: '有声',
    mp4: '视频'
  }.freeze

  FILE_TYPE_ICONS = {
    epub: 'layui-icon-read',
    pdf: 'layui-icon-file-b',
    mp3: 'layui-icon-headset',
    mp4: 'layui-icon-video'
  }.freeze

  FILE_TYPE_COLORS = {
    epub: '#10b981',
    pdf: '#ef4444',
    mp3: '#8b5cf6',
    mp4: '#3b82f6'
  }.freeze

  # 验证
  validates :name, presence: true, length: { maximum: 100 }
  validates :content_file_type, inclusion: { in: FILE_TYPES.values }, allow_blank: true

  # 实例方法
  def file_type_name
    FILE_TYPE_NAMES[content_file_type.to_sym] || content_file_type
  end

  def file_type_icon
    FILE_TYPE_ICONS[content_file_type.to_sym] || 'layui-icon-file'
  end

  def file_type_color
    FILE_TYPE_COLORS[content_file_type.to_sym] || '#6b7280'
  end

  def publish!
    update(is_published: true)
  end

  def unpublish!
    update(is_published: false)
  end

  def toggle_publish
    if is_published?
      unpublish!
      '已下线'
    else
      publish!
      '已上线'
    end
  end

  # 切换免费状态
  def toggle_free
    update(is_free: !is_free)
    is_free? ? '已设为免费' : '已设为付费'
  end
end
