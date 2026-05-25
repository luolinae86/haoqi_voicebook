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

    ext = File.extname(URI.parse(content_file_url.split('?').first).path).downcase
    return if %w[.wav .mp3].exclude?(ext)

    temp_file = Tempfile.new(['chapter', ext])
    begin
      clean_url = content_file_url.split('?').first
      response = HTTParty.get(clean_url, stream_writer: temp_file)
      return unless response.success?

      self.duration = case ext
                      when '.wav' then parse_wav_duration(temp_file.path)
                      when '.mp3' then parse_mp3_duration(temp_file.path)
                      end
    rescue StandardError => e
      Rails.logger.warn("[Chapter] Failed to extract duration: #{e.message}")
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  # 解析 WAV 文件时长（读取 RIFF 头中的 data chunk）
  def parse_wav_duration(file_path)
    content = File.binread(file_path)
    return nil if content.length < 44

    # 查找 fmt chunk 获取音频参数
    fmt_pos = content.index("fmt ")
    return nil if fmt_pos.nil?
    fmt_size = content[fmt_pos + 4, 4].unpack("V")[0]

    sample_rate = content[fmt_pos + 12, 4].unpack("V")[0]
    channels = content[fmt_pos + 10, 2].unpack("v")[0]
    bits_per_sample = content[fmt_pos + 22, 2].unpack("v")[0]
    return nil if sample_rate == 0 || channels == 0 || bits_per_sample == 0

    # 查找 data chunk
    data_pos = content.index("data", fmt_pos + 8 + fmt_size)
    return nil if data_pos.nil?
    data_size = content[data_pos + 4, 4].unpack("V")[0]

    bytes_per_sample = channels * bits_per_sample / 8.0
    (data_size / (sample_rate * bytes_per_sample)).round
  end

  # 解析 MP3 文件时长（通过帧累加）
  def parse_mp3_duration(file_path)
    content = File.binread(file_path)

    # 跳过 ID3v2 tag
    offset = 0
    if content[0, 3] == "ID3"
      tag_size = content[6, 4].bytes.reduce(0) { |acc, b| (acc << 7) | b }
      offset = tag_size + 10
    end

    total_duration = 0.0
    frame_count = 0
    while offset < content.length - 4 && frame_count < 5000
      if content[offset] == "\xFF".b && (content[offset + 1].ord & 0xE0) == 0xE0
        byte2 = content[offset + 1].ord
        version = (byte2 >> 3) & 0x03
        layer = (byte2 >> 1) & 0x03
        bitrate_index = (byte2 >> 4) & 0x0F
        next if version == 1 || layer == 0 || bitrate_index == 0

        byte3 = content[offset + 2].ord
        padding = (byte3 & 0x02) != 0

        # MPEG1 L3
        bitrates = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
        bitrate = bitrates[bitrate_index] * 1000
        sample_rate = version == 3 ? [44100, 48000, 32000][byte3 & 0x03] : 44100
        next if bitrate == 0 || sample_rate == 0

        frame_size = (144 * bitrate / sample_rate.to_f + (padding ? 1 : 0)).to_i
        total_duration += frame_size * 8.0 / bitrate
        frame_count += 1
        offset += frame_size
      else
        offset += 1
      end
    end

    frame_count > 0 ? total_duration.round : nil
  end
end
