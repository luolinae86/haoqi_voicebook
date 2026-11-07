# frozen_string_literal: true

require 'json'

module PictureBook
  # 纯查表注音:整句先按最长词命中 phrase-table,命不中就逐字取常用读音。
  # 表是从 pinyin-pro 3.26 离线导出的(ECS 上没有 node,也不引 ruby-pinyin——
  # 它输出 n̈u/jue 这类拼写,和线上 dict.json 的带声调符号写法对不上),
  # 所以线上跑出来的读音和当初制作 61355 时逐字一致(实测 5 本书 99.77%)。
  module Pinyin
    DATA_DIR = File.expand_path('data', __dir__)
    HAN = /[㐀-䶿一-鿿]/

    class << self
      # 每个字的常用读音(pinyin-pro 无上下文时的返回值),14810 字
      def char_default
        @char_default ||= load_json('char-default.json')
      end

      # 需要上下文才能定音的词 → 逐字读音(165 条,只收「单独命中能自洽」的词)
      def phrase_table
        @phrase_table ||= load_json('phrase-table.json')
      end

      def max_word_length
        @max_word_length ||= phrase_table.keys.map(&:length).max
      end

      # "石子被搬开" -> ["shí","zǐ","bèi","bān","kāi"];非汉字位返回 nil
      def annotate(text)
        chars = text.each_char.to_a
        slots = Array.new(chars.length)
        i = 0
        while i < chars.length
          word = match_word(chars, i)
          if word
            phrase_table[word].each_with_index { |syllable, k| slots[i + k] = syllable }
            i += word.length
          else
            slots[i] = char_default[chars[i]] if chars[i].match?(HAN)
            i += 1
          end
        end
        slots
      end

      def han?(char)
        char.match?(HAN)
      end

      private

      # 从位置 i 起做最长匹配,词内必须全是汉字(否则会把「了,」这类跨标点误判)
      def match_word(chars, i)
        max_word_length.downto(2) do |len|
          next if i + len > chars.length

          window = chars[i, len]
          next unless window.all? { |c| han?(c) }

          word = window.join
          return word if phrase_table.key?(word)
        end
        nil
      end

      def load_json(name)
        JSON.parse(File.read(File.join(DATA_DIR, name), encoding: 'utf-8'))
      end
    end
  end
end
