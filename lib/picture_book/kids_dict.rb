# frozen_string_literal: true

require 'json'

module PictureBook
  # 把随代码提交的 kids-dict.json 灌进 char_definitions（786 字 / 852 个「字+音」条目）。
  # 幂等：按 (character, pinyin) upsert，人工改过的行会被种子覆盖——
  # 真要留人工结果，就把那条改完再从种子文件里删掉。
  module KidsDict
    SOURCE_FILE = File.expand_path('data/kids-dict.json', __dir__)

    class << self
      def raw
        @raw ||= JSON.parse(File.read(SOURCE_FILE, encoding: 'utf-8'))
      end

      def rows
        raw.flat_map do |char, by_reading|
          by_reading.map do |pinyin, defs|
            {
              character: char,
              pinyin: pinyin,
              defs: defs,
              source: 'kids_dict'
            }
          end
        end
      end

      # mysql2 的 upsert 走 ON DUPLICATE KEY UPDATE，命中 (character, pinyin) 唯一索引；
      # 不传 unique_by，这个适配器不支持它。
      def import!
        CharDefinition.upsert_all(rows)
        rows.length
      end
    end
  end
end
