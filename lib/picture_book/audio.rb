# frozen_string_literal: true

require 'open3'

module PictureBook
  # 旁白转码。paraformer-realtime 只吃单声道，且我们按 16k 送帧，
  # 供应商给的 mp3 常是 44.1k 立体声，直接送会只听到一个声道。
  class Audio
    class Error < StandardError; end

    BIN = 'ffmpeg'

    def self.transcode(input, output)
      stdout, stderr, status = Open3.capture3(
        BIN, '-y', '-loglevel', 'error', '-i', input.to_s,
        '-ac', '1', '-ar', '16000', '-codec:a', 'libmp3lame', '-b:a', '48k', output.to_s
      )
      raise Error, "ffmpeg 转码失败: #{(stderr.presence || stdout).to_s[-400, 400]}" unless status.success?

      output
    end

    # 秒数，用来核对 时间.txt 的总时长和音频是否对得上
    def self.duration(input)
      stdout, _stderr, status = Open3.capture3(
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1', input.to_s
      )
      return nil unless status.success?

      stdout.to_s.strip.to_f
    end
  end
end
