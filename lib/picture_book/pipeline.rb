# frozen_string_literal: true

require 'json'

module PictureBook
  # 绘本导入的主流程：资源包 → 逐页 OCR → 整段 ASR → 时间轴 → 两份 JSON → 落库 + 传 OSS。
  #
  # 两次 AI 调用都不便宜也不稳定，原始返回一律先落库：
  #   picture_book_pages.ocr_raw —— 每页的识别原文，重跑时不再认同一页；
  #   books.asr_raw —— 整段旁白的词时间，十几分钟的音频只可能识别一次。
  # 只有 force: true 才重新调用。
  class Pipeline
    class Error < StandardError
    end

    attr_reader :book, :package, :stats, :result

    # upload: false 给本地跑全链路用（不碰 OSS，只落库）
    def initialize(book:, package:, workdir:, oss: nil, upload: true, force: false)
      @book = book
      @package = package
      @workdir = workdir
      @upload = upload
      @force = force
      @oss = oss || (upload ? AliyunOssService.new : nil)
      @ocr_client = OcrClient.new
      @prefix = "books/#{book.source_book_no.presence || book.id}"
      @stats = { ocr_reused: 0, ocr_called: 0, asr_reused: false }
    end

    def call
      upload_media
      ocr = collect_ocr
      sentences = asr_sentences
      @result = Timeline.build(pages: package.pages, ocr_lines: ocr, sentences: sentences)
      store_pages
      render_and_upload
      book.update!(finished_columns) if @upload
      @stats
    end

    # 给不传 OSS 的本地校验用：两份 JSON 的内容
    def json_pair
      [renderer.book_json, renderer.dict_json(renderer.chars_in_order(title_chars: title_chars))]
    end

    private

    def title_chars
      book.name.to_s.each_char.grep(Pinyin::HAN)
    end

    def upload_media
      return unless @upload

      package.pages.each { |page| @oss.upload_file(local_path: page.image_path, object_key: image_key(page)) }
      @audio_key = "#{@prefix}/narration#{File.extname(package.audio_path).downcase}"
      @oss.upload_file(local_path: package.audio_path, object_key: @audio_key)
      return unless package.cover_path

      @cover_key = "#{@prefix}/cover#{File.extname(package.cover_path).downcase}"
      @oss.upload_file(local_path: package.cover_path, object_key: @cover_key)
    end

    def image_key(page)
      "#{@prefix}/#{page.image_name}"
    end

    # 每页存 OCR 原始返回，对外只留切好的朗读行
    def collect_ocr
      lines = {}
      package.pages.each do |page|
        record = book.picture_book_pages.find_or_initialize_by(page_number: page.number)
        record.image_key = image_key(page) if @upload
        raw = record.ocr_raw.presence
        if raw && !@force
          @stats[:ocr_reused] += 1
        else
          source = @upload ? @oss.generate_signed_url(image_key(page), expires: 600) : page.image_path
          raw = @ocr_client.call(source)
          @stats[:ocr_called] += 1
        end
        lines[page.number] = Segmenter.lines(raw['lines'])
        record.ocr_raw = raw
        record.plain_text = lines[page.number].join("\n")
        record.timing_start_ms = page.start_ms
        record.timing_end_ms = page.end_ms
        record.save!
      end
      lines
    end

    # 整段旁白一次识别；逐字时间只有实时口给得起
    def asr_sentences
      if book.asr_raw.present? && !@force
        @stats[:asr_reused] = true
        return book.asr_raw
      end

      mp3 = File.join(@workdir, 'narration-16k.mp3')
      Audio.transcode(package.audio_path, mp3)
      sentences = AsrClient.new(api_key: ENV.fetch('DASHSCOPE_API_KEY')).transcribe(mp3)
      raise Error, 'ASR 没有返回任何句子' if sentences.empty?

      book.update!(asr_raw: sentences)
      sentences
    end

    def store_pages
      @result.pages.each_with_index do |page, index|
        source = package.pages[index]
        record = book.picture_book_pages.find_or_initialize_by(page_number: source.number)
        record.assign_attributes(
          start_ms: page.start_ms,
          end_ms: page.end_ms,
          word_count: page.lines.flat_map(&:tokens).count { |t| t['ch'].match?(Pinyin::HAN) },
          lines: render_page(page, source)
        )
        record.save!
      end
    end

    # 落库的就是 book.json 里那一页的样子（秒、三位小数）：
    # 以后重出 JSON 直接拼页即可，不必再跑一遍时间轴。
    def render_page(page, source)
      {
        'index' => page.index,
        'image' => "#{@prefix}/#{source.image_name}",
        'start' => Package.seconds(page.start_ms),
        'end' => Package.seconds(page.end_ms),
        'lines' => page.lines.map do |line|
          { 'start' => Package.seconds(line.start_ms),
            'end' => Package.seconds(line.end_ms),
            'tokens' => line.tokens }
        end,
        'char_times' => page.lines.flat_map(&:char_times).map { |ms| Package.seconds(ms) }
      }
    end

    def render_and_upload
      book_json, dict_json = json_pair
      @stats.merge!(pages: @result.pages.length, chars: @result.char_count, anchored: @result.anchored)
      return unless @upload

      @book_json_key = "#{@prefix}/book.json"
      @dict_json_key = "#{@prefix}/dict.json"
      @oss.upload_data(data: JSON.generate(book_json), object_key: @book_json_key, content_type: 'application/json')
      @oss.upload_data(data: JSON.generate(dict_json), object_key: @dict_json_key, content_type: 'application/json')
    end

    def finished_columns
      {
        page_count: @result.pages.length,
        word_count: @result.char_count,
        total_duration_ms: package.pages.last.end_ms,
        import_status: :ready,
        imported_at: Time.current,
        import_error_message: nil,
        narration_oss_key: @audio_key,
        narration_oss_url: @oss.public_url(@audio_key),
        cover_image_url: @cover_key && @oss.public_url(@cover_key),
        book_json_oss_key: @book_json_key,
        book_json_oss_url: @oss.public_url(@book_json_key),
        dict_json_oss_key: @dict_json_key,
        dict_json_oss_url: @oss.public_url(@dict_json_key)
      }
    end

    def renderer
      @renderer ||= Renderer.new(
        book_id: book.source_book_no.presence || book.id,
        title: book.name,
        author: book.author&.name,
        oss_prefix: @prefix,
        pages: @result.pages
      )
    end
  end
end
