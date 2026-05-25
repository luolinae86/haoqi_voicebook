# frozen_string_literal: true

# == Schema information
#
# Table name: chapters
#
#  id                :bigint           not null, primary key
#  book_id           :bigint           not null, comment: '所属图书'
#  name              :string           not null, comment: '章节名称'
#  cover_image_url   :string(255)      comment: '章节封面图片URL'
#  content_file_url  :string(255)      comment: '章节内容文件URL（音频/视频）'
#  content_file_name :string(255)      comment: '章节内容文件名'
#  content_file_type :string(255)      comment: '内容文件类型 (mp3/mp4/wav等)'
#  duration          :integer          comment: '音频/视频时长（秒）'
#  is_free           :boolean          default(FALSE), comment: '是否免费'
#  is_published      :boolean          default(FALSE), comment: '是否已发布'
#  sn                :integer          default(0), comment: '排序'
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_chapters_on_book_id  (book_id)
#
class Chapter < ApplicationRecord
  belongs_to :book

  # 内容文件类型
  FILE_TYPES = {
    epub: 'epub',
    pdf: 'pdf',
    mp3: 'mp3',
    mp4: 'mp4',
    wav: 'wav',
  }.freeze

  FILE_TYPE_NAMES = {
    epub: 'EPUB电子书',
    pdf: 'PDF文档',
    mp3: '有声',
    mp4: '视频',
    wav: '有声'
  }.freeze

  FILE_TYPE_ICONS = {
    epub: 'layui-icon-read',
    pdf: 'layui-icon-file-b',
    mp3: 'layui-icon-headset',
    mp4: 'layui-icon-video',
    wav: 'layui-icon-headset'
  }.freeze

  FILE_TYPE_COLORS = {
    epub: '#10b981',
    pdf: '#ef4444',
    mp3: '#8b5cf6',
    mp4: '#3b82f6',
    wav: '#8b5cf6'
  }.freeze

  # 验证
  validates :name, presence: true, length: { maximum: 100 }
  validates :content_file_type, inclusion: { in: FILE_TYPES.values }, allow_blank: true

  # 创建/更新时自动提取时长
  before_validation :extract_duration, if: -> { content_file_url_changed? && content_file_url.present? }

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

  private

  def extract_duration
    return if content_file_url.blank?
    return unless content_file_url.include?('aliyuncs.com')

    require 'streamio-ffmpeg'

    temp_file = Tempfile.new(['chapter', File.extname(URI.parse(content_file_url.split('?').first).path)])
    begin
      clean_url = content_file_url.split('?').first
      response = HTTParty.get(clean_url, stream_writer: temp_file)
      return unless response.success?

      movie = FFMPEG::Movie.new(temp_file.path)
      self.duration = movie.duration.round if movie.duration.present?
    rescue StandardError => e
      Rails.logger.warn("[Chapter] Failed to extract duration: #{e.message}")
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
end
