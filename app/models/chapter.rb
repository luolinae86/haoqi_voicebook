# frozen_string_literal: true

class Chapter < ApplicationRecord
  belongs_to :book

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
