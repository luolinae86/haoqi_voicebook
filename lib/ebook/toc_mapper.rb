# frozen_string_literal: true

module Ebook
  class TocMapper
    LOOKAHEAD_PAGES = 12
    MIN_TOC_MATCHES = 4
    TOC_ENTRY_REGEX = /\A(?<title>.+?)\s*\\?\s*(?<page>\d{1,4})\z/

    def initialize(reader:)
      @reader = reader
      @pages = reader.pages
    end

    def call
      toc_pages, toc_entries = extract_toc_entries
      matched_entries = match_entries_to_pages(toc_entries, toc_pages)

      {
        toc_pages: toc_pages,
        entries: matched_entries,
        page_map: build_page_map(toc_pages, matched_entries)
      }
    end

    private

    def extract_toc_entries
      toc_pages = []
      entries = []

      @pages.first(LOOKAHEAD_PAGES).each do |page|
        begin
          page_entries = page.text.lines.filter_map { |line| parse_toc_entry(line) }
          next if page_entries.size < MIN_TOC_MATCHES

          toc_pages << page.number
          page_entries.each do |entry|
            next if entries.any? { |existing| normalize_lookup(existing[:title]) == normalize_lookup(entry[:title]) }

            entries << entry
          end
        rescue PDF::Reader::MalformedPDFError => e
          # 跳过有问题的页面，继续处理其他页面
          Rails.logger.warn("[TocMapper] Skipping page #{page.number}: #{e.message}")
          next
        end
      end

      [toc_pages, entries]
    end

    def parse_toc_entry(raw_line)
      line = raw_line.to_s.tr("\u3000", " ").strip
      return if line.blank?

      match = line.match(TOC_ENTRY_REGEX)
      return unless match

      title = cleanup_title(match[:title])
      return if title.blank? || title == "目录"

      {
        title: title,
        toc_page_number: match[:page].to_i,
        level: 1,
        source: "toc"
      }
    end

    def cleanup_title(title)
      title.to_s.gsub(/[·•….]{2,}/, " ")
           .gsub(%r{[\\/]+$}, "")
           .gsub(/\s+/, " ")
           .strip
    end

    def match_entries_to_pages(entries, toc_pages)
      search_from = toc_pages.max.to_i + 1

      entries.each_with_object([]) do |entry, matches|
        candidates = title_candidates(entry[:title])
        match_page = (search_from..@pages.size).find do |page_number|
          normalized_page = normalized_page_text(page_number)
          candidates.any? { |candidate| candidate.present? && normalized_page.include?(candidate) }
        end
        next unless match_page

        matches << entry.merge(start_page_number: match_page)
        search_from = match_page + 1
      end
    end

    def title_candidates(title)
      [normalize_lookup(title), normalize_lookup(strip_chapter_prefix(title))].uniq
    end

    def strip_chapter_prefix(title)
      title.to_s.sub(/\A(?:第?[一二三四五六七八九十百零〇\d]+[章节回部卷篇]?)/, "").strip
    end

    def normalized_page_text(page_number)
      @normalized_page_text ||= {}
      @normalized_page_text[page_number] ||= normalize_lookup(@pages[page_number - 1].text.lines.first(10).join(" "))
    end

    def normalize_lookup(text)
      text.to_s.gsub(%r{[[:space:]\\/\-—–·•…"'“”‘’.,，。:：;；!?！？()（）\[\]【】]}, "").downcase
    end

    def build_page_map(toc_pages, entries)
      map = {}

      toc_pages.each do |page_number|
        map[page_number] = {
          title: "目录",
          toc_page_number: nil,
          start_page_number: page_number,
          level: 1,
          source: "toc_index"
        }
      end

      entries.each_with_index do |entry, index|
        last_page = entries[index + 1]&.dig(:start_page_number).to_i
        last_page = last_page.positive? ? last_page - 1 : @pages.size

        (entry[:start_page_number]..last_page).each do |page_number|
          map[page_number] = entry.slice(:title, :toc_page_number, :start_page_number, :level, :source)
        end
      end

      map
    end
  end
end
