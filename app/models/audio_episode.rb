# frozen_string_literal: true

# 有声节目模型
# 管理有声专辑中的单个节目（单集音频内容）
class AudioEpisode < ApplicationRecord
  # 关联关系
  belongs_to :audio_album # 所属专辑

  # 验证规则
  validates :title, presence: true        # 节目标题必填
  validates :sort_order, presence: true   # 排序必填
  validates :duration, numericality: { greater_than: 0 }, allow_nil: true
  validates :play_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 作用域
  scope :ordered, -> { order(sort_order: :asc) }
  scope :free_episodes, -> { where(is_free: true) }
  scope :vip_episodes, -> { where(is_vip: true) }
  scope :published, -> { where("published_at <= ?", Time.current) }

  # 格式化时长显示（秒转为分:秒）
  def formatted_duration
    return "00:00" unless duration&.positive?

    minutes = duration / 60
    seconds = duration % 60
    format("%02d:%02d", minutes, seconds)
  end
end
