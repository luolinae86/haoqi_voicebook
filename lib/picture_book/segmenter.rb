# frozen_string_literal: true

module PictureBook
  # 把 qwen-vl 给出的「视觉行」重新切成「朗读行」。
  #
  # OCR 只能按版面换行给行，一页能给 3 行也能给 10 行；线上发布版的 lines
  # 是标点切分的（每行以一个标点收尾），播放器的高亮粒度靠它。实测 61355 十一页
  # 94 行，用这条规则从 OCR 结果能一行不差地还原出来。
  #
  # 标点半角化（，→, ！→! ？→?）照发布版来：全角逗号在播放器里占满一个字宽，
  # 行尾看着比正文松。。，、；：… 保持原样。
  class Segmenter
    CLOSERS = '，、。！？；：…!?,'.each_char.to_a.freeze
    WIDTH_MAP = { '，' => ',', '！' => '!', '？' => '?', '：' => ':' }.freeze

    class << self
      def lines(ocr_lines)
        text = Array(ocr_lines).join.gsub(/\s+/, '')
        split(text).map { |line| normalize(line) }.reject(&:empty?)
      end

      # 攒「正文 + 紧跟的一串标点」，攒够就收一行。
      # 闭引号不在 CLOSERS 里，所以「！”」这种行尾，”会自己起头成下一行 —— 发布版正是这样。
      def split(text)
        chars = text.each_char.to_a
        lines = []
        i = 0
        n = chars.length
        while i < n
          buffer = +''
          while i < n && !closer?(chars[i])
            buffer << chars[i]
            i += 1
          end
          while i < n && closer?(chars[i])
            buffer << chars[i]
            i += 1
          end
          lines << buffer unless buffer.empty?
        end
        lines
      end

      def closer?(char)
        CLOSERS.include?(char)
      end

      def normalize(line)
        line.each_char.map { |c| WIDTH_MAP.fetch(c, c) }.join
      end
    end
  end
end
