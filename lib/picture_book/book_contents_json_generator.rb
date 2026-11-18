# frozen_string_literal: true

require 'json'
require_relative 'char_dict'
require_relative 'pinyin'
require_relative 'segmenter'
require_relative 'audio'
require_relative 'asr_client'
require_relative '../dash_scope/asr_service'
require_relative '../dash_scope/text_corrector'
require_relative '../dash_scope/punctuation_corrector'

# 从 book_contents（图片页 + 时间戳）+ ASR 语音识别生成 book.json 和 dict.json 并上传 OSS。
# 适用于 haoqi_read 已经上传图片和音频、但没有文本内容的绘本。
module PictureBook
  class BookContentsJsonGenerator
    class Error < StandardError; end

    HAN = Pinyin::HAN
    WIDTH_MAP = Segmenter::WIDTH_MAP

    def initialize(book:)
      @book = book
      @oss = AliyunOssService.new
      @prefix = "books/#{book.source_book_no.presence || book.id}"
    end

    def call
      contents = @book.book_contents.order(:sn).to_a
      raise Error, 'book_contents 为空，无法生成 book.json' if contents.empty?

      sentences = fetch_asr_sentences
      asr_items = flatten_sentences(sentences)
      asr_items = correct_asr_text(asr_items)
      asr_items = correct_asr_punctuation(asr_items)

      # 如果封面页（第1页）时间很短且 ASR 以书名开头，把封面页的 ASR 合并到正文第一页
      merge_until = compute_cover_merge(asr_items, contents)

      pages_data = contents.map.with_index { |c, i| build_page(c, i, asr_items, merge_until) }
      book_json = build_book_json(contents, pages_data)

      book_key = "#{@prefix}/book.json"
      @oss.upload_data(data: JSON.generate(book_json), object_key: book_key, content_type: 'application/json')

      dict_json = build_dict_json(pages_data)
      dict_key = "#{@prefix}/dict.json"
      @oss.upload_data(data: JSON.generate(dict_json), object_key: dict_key, content_type: 'application/json')

      @book.update!(
        book_json_oss_key: book_key,
        book_json_oss_url: @oss.public_url(book_key),
        dict_json_oss_key: dict_key,
        dict_json_oss_url: @oss.public_url(dict_key),
        import_status: :ready,
        imported_at: Time.current,
        page_count: contents.size,
        total_duration_ms: parse_timestamp(contents.last.deal_at)
      )

      { book_json_oss_key: book_key, dict_json_oss_key: dict_key, pages: contents.size }
    end

    private

    # ── ASR ──

    def fetch_asr_sentences
      return @book.asr_raw if @book.asr_raw.present?

      audio_url = @book.file_url.to_s
      raise Error, '绘本没有音频文件' if audio_url.blank?

      signed_url = sign_url_if_needed(audio_url, expires: 3600)
      sentences = DashScope::AsrService.new(api_key: ENV.fetch('DASHSCOPE_API_KEY')).transcribe(signed_url)
      raise Error, 'ASR 未返回任何句子' if sentences.empty?

      @book.update!(asr_raw: sentences)
      sentences
    end

    # 音频可能在不同的 OSS bucket（如 haoqi-read@cn-hangzhou），需要签名才能访问
    def sign_url_if_needed(url, expires: 1800)
      return url unless url.include?('aliyuncs.com') && url.include?('oss-')

      # 从 URL 解析 bucket 和 region: http(s)://BUCKET.oss-REGION.aliyuncs.com/KEY
      uri = URI.parse(url)
      host_parts = uri.host.split('.')
      bucket = host_parts[0]
      region = host_parts[1].sub('oss-', '').sub('-internal', '')
      object_key = uri.path.sub(%r{\A/}, '')

      # haoqi-read bucket 用单独的凭证
      access_key_id, access_key_secret = if bucket == 'haoqi-read'
                                           [ENV['HAOQI_READ_ACCESS_KEY_ID'], ENV['HAOQI_READ_ACCESS_KEY_SECRET']]
                                         else
                                           [OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET]
                                         end

      client = Aliyun::OSS::Client.new(
        endpoint: "https://oss-#{region}.aliyuncs.com",
        access_key_id: access_key_id,
        access_key_secret: access_key_secret
      )
      bucket_obj = client.get_bucket(bucket)
      bucket_obj.object_url(object_key, true, expires)
    rescue StandardError => e
      Rails.logger.warn("[BookContentsJson] URL 签名失败: #{e.message}, 尝试直接使用")
      url
    end

    # 把句子展平成逐字条目（汉字 + 标点，毫秒时间戳）。
    # paraformer-v2 的 words 是逐字的，标点在 punctuation 字段里。
    def flatten_sentences(sentences)
      out = []
      sentences.each do |sentence|
        Array(sentence['words']).each do |word|
          ch = word['text'].to_s
          begin_ms = word['begin_time'].to_i
          out << { 'ch' => ch, 'begin_ms' => begin_ms } if ch.present?

          punct = word['punctuation'].to_s
          if punct.present?
            punct_ms = word['end_time'].to_i
            out << { 'ch' => punct, 'begin_ms' => punct_ms }
          end
        end
      end
      out
    end

    # ── Text correction ──

    # 用 LLM 修正 ASR 文本中的同音错别字，保持时间戳对齐。
    # 策略：只提取汉字送 LLM 纠错（不含标点），避免 LLM 改标点/加字导致对齐失败。
    def correct_asr_text(asr_items)
      return asr_items if asr_items.empty?

      # 记录每个汉字在 asr_items 中的位置
      han_positions = []
      han_text = +""
      asr_items.each_with_index do |item, i|
        if item['ch'].match?(HAN)
          han_positions << i
          han_text << item['ch']
        end
      end
      return asr_items if han_text.empty?

      corrected = DashScope::TextCorrector.new.correct(han_text)
      return asr_items if corrected.blank? || corrected == han_text

      if (corrected.length - han_text.length).abs > han_text.length * 0.05
        Rails.logger.warn("[BookContentsJson] LLM 纠错文本长度差异过大 (#{han_text.length}→#{corrected.length})，跳过")
        return asr_items
      end

      Rails.logger.info("[BookContentsJson] LLM 纠错: #{han_text.length}→#{corrected.length} 汉字")

      # 用纠错后的汉字替换 asr_items 中对应位置的字符
      result = asr_items.dup
      corrected.chars.each_with_index do |ch, ci|
        next unless ci < han_positions.length

        orig_idx = han_positions[ci]
        result[orig_idx] = result[orig_idx].merge('ch' => ch)
      end
      result
    end

    # 用 LLM 修正标点符号错误（错误标点、缺失标点、多余标点）。
    # 策略：先构建完整文本（汉字+标点），送 LLM 修正标点，再映射回时间戳。
    def correct_asr_punctuation(asr_items)
      return asr_items if asr_items.empty?

      full_text = asr_items.map { |item| item['ch'] }.join
      corrected = DashScope::PunctuationCorrector.new.correct(full_text)
      return asr_items if corrected.blank? || corrected == full_text

      orig_han = full_text.each_char.select { |c| c.match?(HAN) }.join
      corrected_han = corrected.each_char.select { |c| c.match?(HAN) }.join

      # 允许 LLM 小幅修改汉字（≤5%），超出则跳过
      han_diff = (orig_han.length - corrected_han.length).abs
      if han_diff > orig_han.length * 0.05
        Rails.logger.warn("[BookContentsJson] LLM 标点纠错汉字变化过大 (#{orig_han.length}→#{corrected_han.length})，跳过")
        return asr_items
      end

      Rails.logger.info("[BookContentsJson] LLM 标点纠错: #{full_text.length}→#{corrected.length} 字符 (汉字差异 #{han_diff})")

      # 收集原始汉字的 asr_items（保留时间戳）
      han_items = asr_items.select { |item| item['ch'].match?(HAN) }

      # 用贪心对齐将修正后的汉字映射到原始时间戳
      orig_han_idx = 0
      result = []

      corrected.each_char do |ch|
        if ch.match?(HAN)
          # 汉字：贪心匹配原始汉字序列
          if orig_han_idx < orig_han.length && ch == orig_han[orig_han_idx]
            # 精确匹配：直接使用原始时间戳
            result << han_items[orig_han_idx].dup if orig_han_idx < han_items.length
            orig_han_idx += 1
          else
            # 不匹配：尝试在后续位置找到匹配（处理 LLM 插入的汉字）
            found = false
            (orig_han_idx + 1...[orig_han_idx + 5, orig_han.length].min).each do |lookahead|
              if ch == orig_han[lookahead]
                orig_han_idx = lookahead + 1
                result << han_items[lookahead].dup if lookahead < han_items.length
                found = true
                break
              end
            end
            unless found
              # 仍然找不到：用前一个汉字的时间戳 + 偏移
              time_ms = result.any? ? result.last['begin_ms'] + 300 : 0
              result << { 'ch' => ch, 'begin_ms' => time_ms }
              orig_han_idx += 1
            end
          end
        else
          # 标点：使用下一个汉字的时间戳（或前一个汉字 + 偏移）
          punct_ms = if orig_han_idx < han_items.length
                       han_items[orig_han_idx]['begin_ms']
                     elsif result.any?
                       result.last['begin_ms'] + 300
                     else
                       0
                     end
          result << { 'ch' => ch, 'begin_ms' => punct_ms }
        end
      end

      result
    end

    # ── Page building ──

    # 检查封面页是否应该合并到正文第一页。
    # 条件：第1页时长 ≤ 5s 且 ASR 以书名开头。
    # 返回合并的截止时间（毫秒），0 表示不合并。
    def compute_cover_merge(asr_items, contents)
      return 0 if contents.size < 2

      cover = contents.first
      cover_duration = parse_timestamp(cover.deal_at) - parse_timestamp(cover.start_at)
      return 0 if cover_duration > 5

      cover_end_ms = (parse_timestamp(cover.deal_at) * 1000).round
      cover_items = asr_items.select { |item| item['begin_ms'] < cover_end_ms }

      # 检查 ASR 是否以书名开头
      title = @book.name.to_s
      cover_text = cover_items.map { |item| item['ch'] }.join
      return 0 unless cover_text.start_with?(title)

      # 找到书名结束后的下一个汉字的位置，合并到那里
      title_len = title.length
      han_items = cover_items.select { |item| item['ch'].match?(HAN) }
      return 0 if han_items.length <= title_len

      # 书名后有泄漏的正文汉字，返回最后一个泄漏汉字的时间 + 1ms
      # 这样正文第一页会包含封面页的所有文字
      cover_end_ms
    end

    def build_page(content, index, asr_items, merge_until = 0)
      start_ms = (parse_timestamp(content.start_at) * 1000).round
      end_ms = (parse_timestamp(content.deal_at) * 1000).round

      # 封面页：只显示书名（去掉 ASR 中书名后泄漏的正文汉字）
      if index.zero? && merge_until > 0
        title = @book.name.to_s
        page_items = asr_items.select { |item| item['begin_ms'] >= start_ms && item['begin_ms'] < end_ms }
        han_count = 0
        cut_idx = page_items.length
        page_items.each_with_index do |item, i|
          han_count += 1 if item['ch'].match?(HAN)
          if han_count >= title.length
            cut_idx = i + 1
            break
          end
        end
        page_items = page_items.first(cut_idx)
      elsif merge_until > 0 && index == 1
        # 正文第一页：包含从 0s 起的全文，跳过书名避免与封面重复
        page_items = asr_items.select { |item| item['begin_ms'] < end_ms }
        title = @book.name.to_s
        han_skipped = 0
        skip_idx = page_items.length
        page_items.each_with_index do |item, i|
          han_skipped += 1 if item['ch'].match?(HAN)
          if han_skipped >= title.length
            skip_idx = i + 1
            break
          end
        end
        page_items = page_items[skip_idx..] || []
      else
        page_items = asr_items.select { |item| item['begin_ms'] >= start_ms && item['begin_ms'] < end_ms }
      end

      # 裁剪页尾不完整的片段（避免跨页泄漏）
      page_items = trim_incomplete_trailing(page_items) unless index.zero? && merge_until > 0
      # 裁剪页首游离的标点（跨页泄漏的另一端）
      page_items = trim_leading_stray(page_items)

      # ASR 识别出的文字 → Segmenter 切成朗读行
      page_text = page_items.map { |item| item['ch'] }.join
      line_texts = page_text.present? ? Segmenter.split(page_text).map { |l| Segmenter.normalize(l) }.reject(&:empty?) : []

      span_ms = end_ms - start_ms

      # 页面开始后的延迟，让叙述者有时间开始说话
      page_delay_ms = if index.zero? && merge_until > 0
                         0  # 封面页：无延迟
                       elsif merge_until > 0 && index == 1
                         600  # 正文第一页（封面合并后）：固定 600ms 延迟
                       else
                         # 后续页面：根据页面时长计算延迟（2%，范围 300-800ms）
                         [(span_ms * 0.02).round, 300].max.tap { |d| [d, 800].min }
                       end

      effective_start_ms = start_ms + page_delay_ms

      # 计算每行在 page_items 中的字符偏移
      line_offsets = []
      offset = 0
      line_texts.each do |text|
        line_offsets << offset
        offset += text.length
      end

      # 计算 ASR 时间范围（第一个和最后一个汉字的时间戳）
      han_items_page = page_items.select { |item| item['ch'].match?(HAN) }
      asr_first_ms = han_items_page.first&.fetch('begin_ms', start_ms) || start_ms
      asr_last_ms = han_items_page.last&.fetch('begin_ms', end_ms) || end_ms
      asr_span_ms = asr_last_ms - asr_first_ms
      page_span_ms = end_ms - effective_start_ms

      # 线性映射：将 ASR 时间戳从 [asr_first_ms, asr_last_ms] 映射到 [effective_start_ms, end_ms]
      # 这样既保持 ASR 的相对时间关系，又确保不超出页面范围
      if asr_span_ms > 0
        time_scale = page_span_ms.to_f / asr_span_ms
      else
        time_scale = 1.0
      end
      time_offset_ms = effective_start_ms - (asr_first_ms * time_scale).round

      # 使用 ASR 字级别时间戳进行精准对齐（应用缩放 + 偏移）
      cursor = { items: page_items, index: 0, time_offset: time_offset_ms, time_scale: time_scale }

      lines = line_texts.map.with_index do |text, line_idx|
        # 计算行边界：使用 ASR 中该行首个汉字的时间，经缩放+偏移映射到页面时间
        line_start_idx = line_offsets[line_idx]
        raw_start_ms = find_line_start_time(page_items, line_start_idx, end_ms)
        line_start_ms = (raw_start_ms * time_scale).round + time_offset_ms

        line_end_ms = if line_idx == line_texts.length - 1
                        end_ms
                      else
                        next_start_idx = line_offsets[line_idx + 1]
                        next_raw = find_line_start_time(page_items, next_start_idx, end_ms)
                        (next_raw * time_scale).round + time_offset_ms
                      end

        # cursor 需要指向当前行的起始位置
        cursor[:index] = line_start_idx
        build_line(text, line_start_ms, line_end_ms, cursor)
      end

      char_times = lines.flat_map { |line| line[:char_times] }

      { lines: lines.map { |l| l.except(:char_times) }, char_times: char_times }
    end

    # 按字数比例分配每个字的时间
    def build_line_proportional(text, line_start_ms, line_end_ms)
      syllables = Pinyin.annotate(text)
      tokens = []
      char_times = []

      len = text.length
      span_ms = line_end_ms - line_start_ms

      text.each_char.with_index do |ch, i|
        # 使用与参考一致的分布公式：charTime[i] = start + (span * i / len)
        # 这样最后一个字符的时间 < end，留出页面间的间隔
        time_ms = if len > 0
                    line_start_ms + (span_ms * i) / len
                  else
                    line_start_ms
                  end
        time_ms = [[time_ms, line_start_ms].max, line_end_ms].min

        if ch.match?(HAN)
          tokens << { 'ch' => ch, 'py' => syllables[i].to_s }
        else
          tokens << { 'ch' => ch, 'py' => '' }
        end
        char_times << (time_ms / 1000.0).round(3)
      end

      {
        'start' => (line_start_ms / 1000.0).round(3),
        'end' => (line_end_ms / 1000.0).round(3),
        'tokens' => tokens,
        char_times: char_times
      }
    end

    # 找到一行在 ASR 中的起始时间（该行首个汉字的时间）
    def find_line_start_time(page_items, line_start_idx, page_end_ms)
      return page_end_ms if line_start_idx >= page_items.length

      # 从 line_start_idx 开始找第一个汉字
      (line_start_idx...page_items.length).each do |idx|
        item = page_items[idx]
        if item['ch'].match?(HAN)
          return item['begin_ms']
        end
      end

      page_end_ms
    end

    # 裁剪页尾不完整的片段，避免跨页文字泄漏。
    # 如果页尾的最后一个片段（到最近的标点为止）只有 ≤3 个汉字，
    # 认为它是从下一页泄漏过来的，裁剪掉。
    def trim_incomplete_trailing(page_items)
      return page_items if page_items.empty?

      # 从后往前找，找到最后一个标点（closer）的位置
      last_closer_idx = nil
      page_items.each_with_index do |item, i|
        last_closer_idx = i if Segmenter.closer?(item['ch'])
      end

      # 如果整个页面都没有标点，不裁剪
      return page_items if last_closer_idx.nil?

      # 最后一个标点之后的内容就是"不完整片段"
      trailing = page_items[(last_closer_idx + 1)..] || []
      trailing_han_count = trailing.count { |item| item['ch'].match?(HAN) }

      # 如果不完整片段 ≤3 个汉字，裁剪掉
      if trailing_han_count > 0 && trailing_han_count <= 3
        page_items.first(last_closer_idx + 1)
      else
        page_items
      end
    end

    # 裁剪页首游离的标点符号（无汉字前缀的标点，从上一页泄漏过来的）。
    def trim_leading_stray(page_items)
      return page_items if page_items.empty?

      # 找到第一个汉字的位置
      first_han_idx = nil
      page_items.each_with_index do |item, i|
        if item['ch'].match?(HAN)
          first_han_idx = i
          break
        end
      end

      # 如果没有汉字，全部裁剪
      return [] if first_han_idx.nil?

      # 如果第一个汉字之前有内容（游离的标点），裁剪掉
      if first_han_idx > 0
        page_items[first_han_idx..]
      else
        page_items
      end
    end

    # 算行边界：每行起点 = 该行首个汉字在 ASR 里的时刻；
    # 行终点 = 下一行起点的 0.64 处（和 Timeline::CUT_FRACTION 同口径）
    def compute_line_boundaries(line_texts, page_items, page_start_ms, page_end_ms)
      return [] if line_texts.empty?

      cut = 0.64

      # 找每行首个汉字在 ASR 序列中的时刻（onset）
      onsets = []
      idx = 0
      line_texts.each do |text|
        han_chars = text.each_char.grep(HAN)
        onset = page_end_ms
        han_chars.each do |ch|
          idx += 1 while idx < page_items.length && page_items[idx]['ch'] != ch
          if idx < page_items.length
            onset = page_items[idx]['begin_ms']
            break
          end
        end
        onsets << onset
      end

      line_texts.map.with_index do |_text, i|
        s = if i.zero?
              onsets[0]
            else
              from = onsets[i - 1]
              to = [onsets[i], from].max
              [[from + ((to - from) * cut).round, from].max, page_end_ms].min
            end

        e = if i < line_texts.length - 1
              from = onsets[i]
              to = [onsets[i + 1], from].max
              [[from + ((to - from) * cut).round, from].max, page_end_ms].min
            else
              page_end_ms
            end

        { start_ms: s, end_ms: e }
      end
    end

    def build_line(text, line_start_ms, line_end_ms, cursor)
      syllables = Pinyin.annotate(text)
      tokens = []
      char_times = []

      han_count = text.each_char.count { |c| c.match?(HAN) }
      han_assigned = 0
      last_time = line_start_ms

      text.each_char.with_index do |ch, i|
        cursor_time = consume_cursor_time(cursor, ch)

        if ch.match?(HAN)
          time_ms = cursor_time || begin
            remaining_han = han_count - han_assigned
            if remaining_han > 0
              (last_time + (line_end_ms - last_time).fdiv(remaining_han)).round
            else
              last_time
            end
          end

          time_ms = [[time_ms, line_start_ms].max, line_end_ms].min
          tokens << { 'ch' => ch, 'py' => syllables[i].to_s }
          char_times << (time_ms / 1000.0).round(3)
          last_time = time_ms
          han_assigned += 1
        else
          time_ms = cursor_time || (char_times.last ? (char_times.last * 1000).round : line_start_ms)
          tokens << { 'ch' => ch, 'py' => '' }
          char_times << (time_ms / 1000.0).round(3)
          last_time = time_ms
        end
      end

      {
        'start' => (line_start_ms / 1000.0).round(3),
        'end' => (line_end_ms / 1000.0).round(3),
        'tokens' => tokens,
        char_times: char_times
      }
    end

    # 从 cursor 中消费一个条目，返回其时间戳（毫秒）。
    # 匹配时考虑 Segmenter.normalize 的全半角转换（，→, ！→! 等）。
    # 如果不匹配（ASR 和文本不一致），返回 nil 且不消费 cursor。
    # 应用 cursor 中的 time_offset 偏移。
    def consume_cursor_time(cursor, ch)
      return nil if cursor[:index] >= cursor[:items].length

      item = cursor[:items][cursor[:index]]
      item_ch = item['ch']
      normalized_item = WIDTH_MAP.fetch(item_ch, item_ch)
      normalized_ch = WIDTH_MAP.fetch(ch, ch)

      if item_ch == ch || normalized_item == normalized_ch
        cursor[:index] += 1
        time_offset = cursor[:time_offset] || 0
        time_scale = cursor[:time_scale] || 1.0
        (item['begin_ms'] * time_scale).round + time_offset
      else
        nil
      end
    end

    # ── JSON builders ──

    LONG_EXPIRY = 10 * 365 * 24 * 3600 # 10 年，绘本资源不变

    def build_book_json(contents, pages_data)
      {
        'id' => @book.source_book_no.presence || @book.id.to_s,
        'title' => @book.name,
        'author' => @book.author&.name,
        'cover' => sign_url_if_needed(@book.cover_image_url.to_s, expires: LONG_EXPIRY),
        'audio' => sign_url_if_needed(@book.file_url.to_s, expires: LONG_EXPIRY),
        'totalDuration' => parse_timestamp(contents.last.deal_at),
        'pageCount' => contents.size,
        'pages' => contents.each_with_index.map do |content, i|
          pd = pages_data[i]
          {
            'index' => i,
            'image' => sign_url_if_needed(content.img_path.to_s, expires: LONG_EXPIRY),
            'start' => parse_timestamp(content.start_at),
            'end' => parse_timestamp(content.deal_at),
            'lines' => pd[:lines],
            'charTimes' => pd[:char_times]
          }
        end
      }
    end

    def build_dict_json(pages_data)
      chars = extract_chars(pages_data)
      return {} if chars.empty?

      CharDict.build(chars)
    end

    def extract_chars(pages_data)
      base_chars = [@book.name, @book.author&.name].compact.join.scan(HAN)
      page_chars = pages_data.flat_map { |pd| pd[:lines] }
                             .flat_map { |line| line['tokens'].map { |t| t['ch'] } }
                             .grep(HAN)
      (base_chars + page_chars).uniq
    end

    # ── Helpers ──

    def parse_timestamp(str)
      return 0.0 if str.blank?

      cleaned = str.to_s.strip.gsub(/\r/, '')
      parts = cleaned.split(':')
      return 0.0 unless parts.size == 2

      parts[0].to_f * 60 + parts[1].to_f
    end
  end
end
