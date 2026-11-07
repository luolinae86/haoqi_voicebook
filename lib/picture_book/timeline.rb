# frozen_string_literal: true

module PictureBook
  # 把 OCR 出的行 + ASR 出的字时间，摊成 book.json 要的「页 → 行 → 逐字」时间轴。
  #
  # 三条从线上数据里量出来的规矩：
  #   1. 发布的窗口是首尾相接的（page.end == 下一页.start，行与行也一样），
  #      所以每行只需要定起点，终点取下一行的起点。
  #   2. 行/页的切点落在两行的空档里：上一行末字 onset → 下一行首字 onset，
  #      按 0.64 分。取 0.5 会卡在字头之前（读完那句才翻页，画面慢半拍），
  #      0.64 是 61355 人工校对时定下的位置。
  #   3. 页窗口用供应商 时间.txt 给的，ASR 只管页内的行和字。
  #
  # 字级时间来自 SequenceMatcher：对得上的用 ASR 的 onset，对不上的在相邻锚点间
  # 均分，并且一律夹回自己页的窗口里（和 scripts/align/align.py 一个思路）。
  class Timeline
    CUT_FRACTION = 0.64
    HAN = Pinyin::HAN

    Result = Struct.new(:pages, :char_count, :anchored, keyword_init: true)
    Line = Struct.new(:start_ms, :end_ms, :tokens, :char_times, keyword_init: true)
    PageWindow = Struct.new(:index, :image_name, :start_ms, :end_ms, :lines, keyword_init: true)

    # sentences: PictureBook::AsrClient#transcribe 的返回
    # ocr_lines: {页码(1-based) => [行文本]}
    # pages:     PictureBook::Package#pages
    def self.build(pages:, ocr_lines:, sentences:)
      new(pages: pages, ocr_lines: ocr_lines, sentences: sentences).build
    end

    def initialize(pages:, ocr_lines:, sentences:)
      @pages = pages
      @ocr_lines = ocr_lines
      @asr = flatten_sentences(sentences)
    end

    def build
      expected = build_expected
      times = align(expected)
      anchored = times.compact.length
      interpolate(expected, times)
      expected.each_with_index do |item, i|
        item[:time_ms] = clamp(times[i], page_start_ms(item[:page]), page_end_ms(item[:page]))
      end
      make_monotone(expected)

      pages = @pages.each_with_index.map do |page, index|
        slice = expected.select { |e| e[:page] == index }
        PageWindow.new(
          index: index,
          image_name: page.image_name,
          start_ms: page.start_ms,
          end_ms: page.end_ms,
          lines: build_lines(page, slice)
        )
      end

      Result.new(pages: pages, char_count: expected.length, anchored: anchored)
    end

    # 一行里能出声的字（标点不算），空行整行丢掉
    def voiced_lines(page_number)
      @voiced_lines ||= {}
      @voiced_lines[page_number] ||= Array(@ocr_lines[page_number])
                                     .select { |text| text.each_char.any? { |c| c.match?(HAN) } }
    end

    private

    # ASR 一个词可能一次给出好几个汉字，按时间均分到字（align.py 同款）
    def flatten_sentences(sentences)
      out = []
      sentences.each do |sentence|
        Array(sentence['words']).each do |word|
          chars = word['text'].to_s.each_char.grep(HAN)
          next if chars.empty?

          begin_ms = word['begin_time'].to_i
          span = (word['end_time'].to_i - begin_ms).fdiv(chars.length)
          chars.each_with_index do |ch, k|
            out << { 'ch' => ch,
                     'begin_ms' => (begin_ms + (k * span)).round,
                     'end_ms' => (begin_ms + ((k + 1) * span)).round }
          end
        end
      end
      out
    end

    def build_expected
      list = []
      @pages.each_with_index do |page, index|
        voiced_lines(page.number).each_with_index do |text, line_index|
          text.each_char.with_index do |ch, char_index|
            next unless ch.match?(HAN)

            list << { ch: ch, page: index, line: line_index, char: char_index, time_ms: nil }
          end
        end
      end
      list
    end

    def align(expected)
      mine = expected.map { |e| e[:ch] }
      theirs = @asr.map { |a| a['ch'] }
      times = Array.new(expected.length)
      SequenceMatcher.new(mine, theirs).matching_blocks.each do |block|
        block.width.times do |k|
          times[block.start_a + k] = @asr[block.start_b + k]['begin_ms']
        end
      end
      times
    end

    # 连续没对上的字，在左右锚点（或页边界）之间均分
    def interpolate(expected, times)
      n = expected.length
      i = 0
      while i < n
        i += 1 and next if times[i]

        j = i
        j += 1 while j < n && times[j].nil?
        left = i.zero? ? page_start_ms(expected[i][:page]) : times[i - 1]
        right = j >= n ? page_end_ms(expected[n - 1][:page]) : times[j]
        span = (right - left).fdiv(j - i + 1)
        (i...j).each_with_index { |k, m| times[k] = (left + ((m + 1) * span)).round }
        i = j
      end
      times
    end

    def make_monotone(expected)
      run = 0
      expected.each do |item|
        item[:time_ms] = [item[:time_ms], run].max
        run = item[:time_ms]
      end
    end

    def build_lines(page, slice)
      windows = line_windows(page, slice)
      texts = voiced_lines(page.number)

      windows.map do |window|
        items = slice.select { |e| e[:line] == window[:line] }
        text = texts[window[:line]]
        syllables = Pinyin.annotate(text)
        time_by_char = items.to_h { |e| [e[:char], e[:time_ms]] }

        tokens = []
        char_times = []
        cursor = window[:start_ms]
        text.each_char.with_index do |ch, i|
          if ch.match?(HAN)
            tokens << { 'ch' => ch, 'py' => syllables[i].to_s }
            cursor = time_by_char[i] || cursor
          else
            tokens << { 'ch' => ch, 'py' => '' }
          end
          char_times << cursor # 标点不出声，继承前一个字，播放器不闪
        end

        Line.new(start_ms: window[:start_ms], end_ms: window[:end_ms], tokens: tokens, char_times: char_times)
      end
    end

    def line_windows(page, slice)
      lines = slice.group_by { |e| e[:line] }.sort_by { |line, _| line }
      return [] if lines.empty?

      onsets = lines.to_h { |line, items| [line, items.first[:time_ms]] }
      codas = lines.to_h { |line, items| [line, items.last[:time_ms]] }

      starts = {}
      lines.each_with_index do |(line, _items), k|
        starts[line] =
          if k.zero?
            page.start_ms
          else
            previous = lines[k - 1][0]
            from = [codas[previous], starts[previous]].max
            to = [onsets[line], from].max
            clamp(from + ((to - from) * CUT_FRACTION).round, starts[previous], page.end_ms)
          end
      end

      lines.each_with_index.map do |(line, _items), k|
        stop = k + 1 < lines.length ? starts[lines[k + 1][0]] : page.end_ms
        { line: line, start_ms: starts[line], end_ms: [stop, starts[line]].max }
      end
    end

    def page_start_ms(index)
      @pages[index].start_ms
    end

    def page_end_ms(index)
      @pages[index].end_ms
    end

    def clamp(value, low, high)
      [[value, low].max, high].min
    end
  end
end
