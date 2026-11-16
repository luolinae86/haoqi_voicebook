# frozen_string_literal: true

require 'json'

# 从 book_contents（haoqi_read 写入的图片页 + 时间戳）直接生成 book.json 并上传 OSS。
# 不走 OCR/ASR pipeline，适用于 haoqi_read 已经单独上传图片和音频的绘本。
module PictureBook
  class BookContentsJsonGenerator
    class Error < StandardError; end

    def initialize(book:)
      @book = book
      @oss = AliyunOssService.new
      @prefix = "books/#{book.source_book_no.presence || book.id}"
    end

    def call
      contents = @book.book_contents.order(:sn).to_a
      raise Error, "book_contents 为空，无法生成 book.json" if contents.empty?

      book_json = build_book_json(contents)
      json_key = "#{@prefix}/book.json"

      @oss.upload_data(
        data: JSON.generate(book_json),
        object_key: json_key,
        content_type: 'application/json'
      )

      @book.update!(
        book_json_oss_key: json_key,
        book_json_oss_url: @oss.public_url(json_key),
        import_status: :ready,
        imported_at: Time.current,
        page_count: contents.size,
        total_duration_ms: parse_timestamp(contents.last.deal_at)
      )

      { book_json_oss_key: json_key, pages: contents.size }
    end

    private

    def build_book_json(contents)
      {
        'id' => @book.source_book_no.presence || @book.id,
        'title' => @book.name,
        'author' => @book.author&.name,
        'cover' => @book.cover_image_url.to_s,
        'audio' => @book.file_url.to_s,
        'totalDuration' => parse_timestamp(contents.last.deal_at),
        'pageCount' => contents.size,
        'pages' => contents.map.with_index { |c, i| build_page(c, i) }
      }
    end

    def build_page(content, index)
      {
        'index' => index,
        'image' => content.img_path.to_s,
        'start' => parse_timestamp(content.start_at),
        'end' => parse_timestamp(content.deal_at),
        'lines' => [],
        'charTimes' => []
      }
    end

    # 解析 "M:SS.mmm" / "MM:SS.mmm" 格式为秒数（浮点），容忍尾部 \r
    def parse_timestamp(str)
      return 0.0 if str.blank?

      cleaned = str.to_s.strip.gsub(/\r/, '')
      parts = cleaned.split(':')
      return 0.0 unless parts.size == 2

      minutes = parts[0].to_f
      seconds = parts[1].to_f
      minutes * 60 + seconds
    end
  end
end
