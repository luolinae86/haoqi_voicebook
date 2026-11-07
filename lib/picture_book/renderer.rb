# frozen_string_literal: true

require 'json'

module PictureBook
  # 把 Timeline 的结果拼成线上播放器在读的两份 JSON。
  # 键顺序、数值格式都是照发布版 book.json 反推的（秒、三位小数、pages 从 0 起），
  # 改动会让前端 diff 出整本重下，别顺手「优化」结构。
  class Renderer
    # oss_prefix: 这本绘本在 OSS 上的目录，如 "books/61355"
    def initialize(book_id:, title:, oss_prefix:, pages:, author: nil)
      @book_id = book_id
      @title = title
      @author = author
      @prefix = oss_prefix.to_s.sub(%r{/\z}, '')
      @pages = pages
    end

    def book_json
      {
        'id' => @book_id,
        'title' => @title,
        'author' => @author,
        'cover' => "#{@prefix}/cover.jpg",
        'audio' => "#{@prefix}/narration.mp3",
        'totalDuration' => seconds(@pages.last&.end_ms),
        'pageCount' => @pages.length,
        'pages' => @pages.map { |page| render_page(page) }
      }
    end

    # kw（生词高亮）是人工标的，自动生成时不带这个键
    def keyword_chars
      @keyword_chars ||= @pages.flat_map do |page|
        page.lines.flat_map { |line| line.tokens.select { |t| t['kw'] }.map { |t| t['ch'] } }
      end.uniq
    end

    def dict_json(chars_in_order)
      CharDict.build(chars_in_order, keyword_chars: keyword_chars)
    end

    # dict.json 的键序 = 全书汉字首次出现序（封面标题在前，和发布版一致）
    def chars_in_order(title_chars: [])
      seen = {}
      order = []
      (title_chars + all_hans).each do |ch|
        next if seen[ch]

        seen[ch] = true
        order << ch
      end
      order
    end

    def all_hans
      @pages.flat_map { |page| page.lines.flat_map { |line| line.tokens.map { |t| t['ch'] } } }
            .grep(Pinyin::HAN)
    end

    def to_json_pair
      [JSON.generate(book_json), JSON.generate(dict_json(chars_in_order(title_chars: @title.to_s.each_char.to_a)))]
    end

    private

    def render_page(page)
      tokens = page.lines.flat_map(&:tokens)
      {
        'index' => page.index,
        'image' => "#{@prefix}/#{page.image_name}",
        'start' => seconds(page.start_ms),
        'end' => seconds(page.end_ms),
        'lines' => page.lines.map do |line|
          {
            'start' => seconds(line.start_ms),
            'end' => seconds(line.end_ms),
            'tokens' => line.tokens
          }
        end,
        'charTimes' => page.lines.flat_map(&:char_times).map { |ms| seconds(ms) }
      }.tap do |hash|
        hash['charTimes'] = hash['charTimes'][0, tokens.length]
      end
    end

    def seconds(ms)
      (ms.to_f / 1000).round(3)
    end
  end
end
