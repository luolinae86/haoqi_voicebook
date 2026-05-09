# == Schema Information
#
# Table name: audio_albums
#
#   id                   integer(8)         not null, primary key
#   book_id              integer(4)         not null
#   narrator             string(255)        
#   total_episodes       integer(4)         not null, default(0)
#   total_duration       integer(4)         not null, default(0)
#   description          text(65535)        
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_audio_albums_on_book_id on book_id (unique)
#
#
# frozen_string_literal: true

# 有声专辑模型
# 管理有声书的专辑信息（主讲人、总集数、总时长等）
class AudioAlbum < ApplicationRecord
  # 关联关系
  belongs_to :book                                    # 关联的图书
  has_many :audio_episodes, dependent: :destroy       # 包含的节目

  # 验证规则
  validates :book_id, presence: true, uniqueness: true # 一本书只能有一个专辑
  validates :total_episodes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_duration, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # 格式化总时长显示（秒转为时:分:秒）
  def formatted_duration
    return "00:00:00" unless total_duration&.positive?

    hours = total_duration / 3600
    minutes = (total_duration % 3600) / 60
    seconds = total_duration % 60
    format("%02d:%02d:%02d", hours, minutes, seconds)
  end
end
