# frozen_string_literal: true

# 单字低幼释义，dict.json 里 readings[].defs 的来源。
# 只存「字 + 读音 → 释义」这一件需要人工改的事：
# 部首/笔画/是否多音字是静态语言资料，走 lib/picture_book/data 里的种子表，不在这里冗余。
class CharDefinition < ApplicationRecord
  SOURCES = %w[kids_dict qwen manual].freeze

  validates :character, presence: true
  validates :pinyin, presence: true, uniqueness: { scope: :character }
  validates :source, inclusion: { in: SOURCES }

  scope :for_chars, ->(chars) { where(character: chars) }

  # dict.json 要的是数组，原样存原样出；缺释义的字渲染成空数组
  def defs_array
    defs.is_a?(Array) ? defs : []
  end
end
