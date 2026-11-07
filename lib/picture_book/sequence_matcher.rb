# frozen_string_literal: true

module PictureBook
  # difflib.SequenceMatcher(None, a, b, autojunk=False).get_matching_blocks() 的等价实现。
  # 逐字对齐靠它把「已知原文」和「ASR 出的字」配对；照抄 CPython 的取块规则
  # （最长块优先，同长取 a 里最靠前、b 里最靠后），换一种 LCS 会得到不同的错配点。
  class SequenceMatcher
    # difflib 的匹配块三元组；成员不能叫 :size / :length，都会盖掉 Struct 自己的方法
    Match = Struct.new(:start_a, :start_b, :width)

    def initialize(a, b)
      @a = a
      @b = b
      @b2j = Hash.new { |h, k| h[k] = [] }
      @b.each_with_index { |ch, j| @b2j[ch] << j }
    end

    def matching_blocks
      blocks = []
      queue = [[0, @a.length, 0, @b.length]]
      while (alo, ahi, blo, bhi = queue.pop)
        i, j, k = find_longest_match(alo, ahi, blo, bhi)
        next unless k > 0

        blocks << Match.new(i, j, k)
        queue << [alo, i, blo, j] if alo < i && blo < j
        queue << [i + k, ahi, j + k, bhi] if i + k < ahi && j + k < bhi
      end
      blocks.sort_by! { |m| [m.start_a, m.start_b] }
      blocks << Match.new(@a.length, @b.length, 0)
      blocks
    end

    private

    def find_longest_match(alo, ahi, blo, bhi)
      a = @a
      b = @b
      b2j = @b2j
      best_i = alo
      best_j = blo
      best_size = 0
      j2len = {}

      (alo...ahi).each do |i|
        newj2len = {}
        b2j[a[i]].each do |j|
          next if j < blo
          break if j >= bhi

          k = (j2len[j - 1] || 0) + 1
          newj2len[j] = k
          next unless k > best_size

          best_i = i - k + 1
          best_j = j - k + 1
          best_size = k
        end
        j2len = newj2len
      end

      # 用 j2len 没覆盖到的相等字符继续往两头扩（b 里位置重复时的补扩）
      while best_i > alo && best_j > blo && a[best_i - 1] == b[best_j - 1]
        best_i -= 1
        best_j -= 1
        best_size += 1
      end
      while best_i + best_size < ahi && best_j + best_size < bhi &&
            a[best_i + best_size] == b[best_j + best_size]
        best_size += 1
      end
      # 越界裁剪
      while best_i < alo && best_i + best_size <= ahi &&
            a[best_i + best_size] == b[best_j - 1]
        best_size -= 1
      end
      while best_j < blo && best_j + best_size <= bhi &&
            b[best_j + best_size] == a[best_i - 1]
        best_i -= 1
        best_j -= 1
        best_size -= 1
      end

      [best_i, best_j, best_size]
    end
  end
end
