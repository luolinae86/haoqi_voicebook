# frozen_string_literal: true

require 'json'
require 'open-uri'
require 'tmpdir'
require_relative 'char_dict'
require_relative 'pinyin'
require_relative 'segmenter'
require_relative 'audio'
require_relative 'asr_client'

# 从 book_contents（图片页 + 时间戳）+ ASR 语音识别生成 book.json 和 dict.json 并上传 OSS。
# 适用于 haoqi_read 已经上传图片和音频、但没有文本内容的绘本。
module PictureBook
  class BookContentsJsonGenerator
    class Error < StandardError; end

    HAN = Pinyin::HAN
    PUNCT = /\p{P}/
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

      pages_data = contents.map.with_index { |c, i| build_page(c, i, asr_items) }
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

      Dir.mktmpdir('voicebook-asr-') do |dir|
        raw_path = File.join(dir, 'audio.mp3')
        transcode_path = File.join(dir, 'audio-16k.mp3')

        # 下载音频到临时文件（跨 bucket 时先签名）
        download_audio(audio_url, raw_path)
        # 转码为 16kHz 单声道 mp3（AsrClient 要求）
        Audio.transcode(raw_path, transcode_path)
        # 实时 ASR（WebSocket 流式识别，字级时间是声学对齐的）
        sentences = AsrClient.new(api_key: ENV.fetch('DASHSCOPE_API_KEY')).transcribe(transcode_path)
        raise Error, 'ASR 未返回任何句子' if sentences.empty?

        @book.update!(asr_raw: sentences)
        sentences
      end
    end

    def download_audio(url, dest_path)
      signed = sign_url_if_needed(url)
      URI.open(signed) { |remote| File.open(dest_path, 'wb') { |local| local.write(remote.read) } }
    end

    # 音频可能在不同的 OSS bucket（如 haoqi-read@cn-hangzhou），需要签名才能下载
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
    # ASR 的 words 只有汉字，标点在 sentence.text 里；
    # 用两指针对齐 text 和 word chars，把标点插回时间线。
    def flatten_sentences(sentences)
      out = []
      sentences.each do |sentence|
        words = Array(sentence['words'])
        text = sentence['text'].to_s

        word_chars = []
        words.each do |word|
          chars = word['text'].to_s.each_char.select { |c| c.match?(HAN) }
          next if chars.empty?

          begin_ms = word['begin_time'].to_i
          end_ms = word['end_time'].to_i
          span = chars.length > 1 ? (end_ms - begin_ms).fdiv(chars.length) : 0
          chars.each_with_index do |ch, k|
            word_chars << { ch: ch, begin_ms: (begin_ms + k * span).round }
          end
        end

        wi = 0
        last_ms = 0
        text.each_char do |ch|
          if ch.match?(HAN)
            if wi < word_chars.length && word_chars[wi][:ch] == ch
              out << { 'ch' => ch, 'begin_ms' => word_chars[wi][:begin_ms] }
              last_ms = word_chars[wi][:begin_ms]
              wi += 1
            end
          elsif ch.match?(PUNCT)
            punct_ms = if wi > 0 && wi < word_chars.length
                         (word_chars[wi - 1][:begin_ms] + word_chars[wi][:begin_ms]) / 2
                       elsif wi > 0
                         last_ms
                       elsif wi < word_chars.length
                         word_chars[wi][:begin_ms]
                       else
                         0
                       end
            out << { 'ch' => ch, 'begin_ms' => punct_ms }
            last_ms = punct_ms
          end
        end
      end
      out
    end

    # ── Page building ──

    def build_page(content, index, asr_items)
      start_ms = (parse_timestamp(content.start_at) * 1000).round
      end_ms = (parse_timestamp(content.deal_at) * 1000).round

      # 按时间窗口选出本页的 ASR 逐字条目
      page_items = asr_items.select { |item| item['begin_ms'] >= start_ms && item['begin_ms'] < end_ms }

      # ASR 识别出的文字 → Segmenter 切成朗读行
      page_text = page_items.map { |item| item['ch'] }.join
      line_texts = page_text.present? ? Segmenter.split(page_text).map { |l| Segmenter.normalize(l) }.reject(&:empty?) : []

      # 按顺序消费 page_items，给每行每个字分配时间
      cursor = { index: 0, items: page_items }
      # 先算每行的起止时间（行边界落在句间停顿的 0.64 处，和 Timeline 同口径）
      line_boundaries = compute_line_boundaries(line_texts, page_items, start_ms, end_ms)

      lines = line_texts.map.with_index do |text, line_idx|
        boundary = line_boundaries[line_idx]
        build_line(text, boundary[:start_ms], boundary[:end_ms], cursor)
      end

      char_times = lines.flat_map { |line| line[:char_times] }

      { lines: lines.map { |l| l.except(:char_times) }, char_times: char_times }
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
        onsets << [onset, page_start_ms].max
      end

      line_texts.map.with_index do |_text, i|
        s = if i.zero?
              page_start_ms
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
        # 尝试从 cursor 中消费一个条目（匹配时考虑 Segmenter.normalize 的全半角转换）
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
    def consume_cursor_time(cursor, ch)
      return nil if cursor[:index] >= cursor[:items].length

      item = cursor[:items][cursor[:index]]
      item_ch = item['ch']
      normalized_item = WIDTH_MAP.fetch(item_ch, item_ch)
      normalized_ch = WIDTH_MAP.fetch(ch, ch)

      if item_ch == ch || normalized_item == normalized_ch
        cursor[:index] += 1
        item['begin_ms']
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
