# == Schema Information
#
# Table name: reading_levels
#
#   id                   integer(8)         not null, primary key
#   name                 string(255)        not null
#   level                integer(4)         not null
#   description          text(65535)        
#   created_at           datetime           not null
#   updated_at           datetime           not null
#
#  Index: index_reading_levels_on_level on level (unique)
#
#
# frozen_string_literal: true

# 分级阅读模型
# 管理分级阅读的级别（1级、2级、3级等）
class ReadingLevel < ApplicationRecord
  # 验证规则
  validates :name, presence: true, uniqueness: true
  validates :level, presence: true, uniqueness: true

  # 作用域
  scope :ordered, -> { order(level: :asc) }
end
