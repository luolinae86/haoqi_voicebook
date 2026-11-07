# frozen_string_literal: true

require 'fileutils'
require 'zip'

module PictureBook
  # 供应商资源包：页面图 + 一条整段朗读 mp3 + 时间.txt。
  # 时间.txt 一行一页：`01.jpg,0:02.501-0:42.734`（会有行尾制表符、末行不带换行这类脏数据）。
  # 包可能是目录，也可能是 hao_qi_read 传上来的 zip。
  class Package
    class Error < StandardError
    end

    IMAGE_EXTS = %w[.jpg .jpeg .png .webp].freeze
    TIMING_ROW = /\A\s*(?<image>[^,]+?)\s*,\s*(?<start>\d+:\d+(?:\.\d+)?)\s*-\s*(?<end>\d+:\d+(?:\.\d+)?)\s*\z/

    Page = Struct.new(:number, :image_path, :image_name, :start_ms, :end_ms, keyword_init: true)

    attr_reader :dir, :audio_path, :cover_path, :timing_path, :pages

    # source: 目录路径，或 zip 路径（解到 tmpdir 里）
    def self.open(source, tmpdir:)
      dir = File.directory?(source) ? source : extract_zip(source, tmpdir)
      new(dir)
    end

    def self.extract_zip(zip_path, tmpdir)
      target = File.join(tmpdir, 'package')
      FileUtils.mkdir_p(target)
      Zip::File.open(zip_path) do |zip|
        zip.each do |entry|
          name = entry.name
          next if name.include?('__MACOSX') || File.basename(name).start_with?('.')
          next if entry.directory?

          # zip 里的路径是外部数据，挡掉绝对路径和 ../ 往上级写
          clean = name.split('/').reject { |seg| seg == '.' || seg == '..' || seg.empty? }.join('/')
          raise Error, "资源包内文件名不合法: #{name}" if clean.empty?

          path = File.join(target, clean)
          FileUtils.mkdir_p(File.dirname(path))
          entry.get_input_stream { |io| File.binwrite(path, io.read) }
        end
      end
      # 供应商常在 zip 里垫一层同名目录，把它拍平
      entries = Dir.children(target)
      if entries.size == 1 && File.directory?(File.join(target, entries.first))
        File.join(target, entries.first)
      else
        target
      end
    end

    def initialize(dir)
      @dir = File.expand_path(dir)
      @audio_path = find_one!('朗读音频', Dir[File.join(@dir, '**', '*.mp3')])
      @timing_path = find_one!('时间.txt', Dir[File.join(@dir, '**', '*时间*.txt')])
      @cover_path = Dir[File.join(@dir, '*')].find { |f| File.basename(f) =~ /封面|cover/i }
      @pages = build_pages
    end

    # 供 worker 记日志用
    def summary
      "音频 #{File.basename(audio_path)} · #{pages.length} 页 · 时长 #{(pages.last&.end_ms || 0) / 1000.0}s"
    end

    # 秒（给 book.json 用，线上就是秒 + 三位小数）
    def self.seconds(ms)
      (ms.to_f / 1000).round(3)
    end

    # "1:09.061" -> 69061
    def self.timing_to_ms(text)
      minutes, rest = text.split(':', 2)
      seconds, fraction = rest.split('.', 2)
      (((minutes.to_i * 60) + seconds.to_i) * 1000) + fraction.to_s.ljust(3, '0')[0, 3].to_i
    end

    private

    def find_one!(label, matches)
      raise Error, "资源包里找不到#{label}: #{@dir}" if matches.empty?
      raise Error, "资源包里#{label}有多个: #{matches.map { |f| File.basename(f) }.join(', ')}" if matches.length > 1

      matches.first
    end

    def page_images
      Dir.children(@dir)
         .select { |name| IMAGE_EXTS.include?(File.extname(name).downcase) && name !~ /封面|cover/i }
         .sort_by { |name| [leading_number(name), name] }
    end

    # 注意别用 Integer("08")：前导零会被当成八进制直接报错，01~09 全得掉到兜底值。
    def leading_number(name)
      digits = name[/\A\d+/]
      digits ? digits.to_i : 1_000_000
    end

    def timings
      rows = File.read(timing_path, encoding: 'UTF-8').split(/\r?\n/)
      rows.filter_map do |row|
        next if row.strip.empty?

        m = TIMING_ROW.match(row)
        raise Error, "时间.txt 行看不懂: #{row.inspect}" unless m

        { image: m[:image], start_ms: self.class.timing_to_ms(m[:start]), end_ms: self.class.timing_to_ms(m[:end]) }
      end
    end

    def build_pages
      images = page_images
      by_name = images.to_h { |name| [name, name] }
      rows = timings
      raise Error, "时间.txt 有 #{rows.length} 页，图只有 #{images.length} 张" if rows.length > images.length

      rows.each_with_index.map do |row, i|
        name = File.basename(row[:image])
        # 时间.txt 里的文件名是准的；对不上再退回按 01.jpg 顺序数
        actual = by_name[name] || images[i]
        warn_once("时间.txt 写的 #{name} 在包里找不到，按顺序用 #{actual}") unless by_name[name]

        Page.new(
          number: i + 1,
          image_path: File.join(@dir, actual),
          image_name: actual,
          start_ms: row[:start_ms],
          end_ms: row[:end_ms]
        )
      end
    end

    def warn_once(message)
      defined?(Rails) ? Rails.logger.warn("[PictureBook::Package] #{message}") : warn("[PictureBook::Package] #{message}")
    end
  end
end
