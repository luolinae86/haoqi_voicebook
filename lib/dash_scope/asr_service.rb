# frozen_string_literal: true

require 'httparty'
require 'json'

module DashScope
  # DashScope 文件转写 ASR（paraformer-v2）。
  # 接收公网可访问的音频 URL，返回句子 + 词级时间戳。
  # 输出格式与 PictureBook::AsrClient（实时口）保持一致，方便下游共用。
  class AsrService
    class Error < StandardError; end

    SUBMIT_URL = 'https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription'
    TASK_URL   = 'https://dashscope.aliyuncs.com/api/v1/tasks/%s'
    MODEL      = 'paraformer-v2'

    def initialize(api_key: ENV['DASHSCOPE_API_KEY'])
      @api_key = api_key
      raise Error, 'DASHSCOPE_API_KEY not set' if @api_key.blank?
    end

    # 提交音频转写，返回与 AsrClient#transcribe 同构的句子数组。
    # 每个句子: { 'sentence_id' => N, 'text' => '...', 'begin_time' => ms, 'end_time' => ms,
    #             'words' => [{ 'text' => '...', 'begin_time' => ms, 'end_time' => ms }] }
    def transcribe(audio_url, timeout: 300)
      task_id = submit_task(audio_url)
      output = poll_task(task_id, timeout: timeout)
      parse_sentences(output)
    end

    private

    def submit_task(audio_url)
      response = HTTParty.post(
        SUBMIT_URL,
        headers: headers.merge('X-DashScope-Async' => 'enable'),
        body: {
          model: MODEL,
          input: { file_urls: [audio_url] },
          parameters: { language_hints: ['zh'] }
        }.to_json
      )

      body = JSON.parse(response.body)
      raise Error, "ASR 提交失败: #{body['message'] || response.code}" unless response.success? && body['output']

      task_id = body.dig('output', 'task_id')
      raise Error, 'ASR 提交失败: 未返回 task_id' unless task_id

      Rails.logger.info("[DashScope::AsrService] 提交任务: task_id=#{task_id}")
      task_id
    end

    def poll_task(task_id, timeout:)
      deadline = Time.current + timeout
      url = format(TASK_URL, task_id)

      loop do
        raise Error, "ASR 任务超时: task_id=#{task_id}" if Time.current > deadline

        response = HTTParty.get(url, headers: headers)
        body = JSON.parse(response.body)
        raise Error, "ASR 查询失败: #{body['message'] || response.code}" unless response.success?

        status = body.dig('output', 'task_status')
        case status
        when 'SUCCEEDED'
          return body['output']
        when 'FAILED'
          raise Error, "ASR 任务失败: #{body.dig('output', 'message') || 'unknown'}"
        when 'PENDING', 'RUNNING'
          sleep 3
        else
          raise Error, "ASR 任务未知状态: #{status}"
        end
      end
    end

    # 把 file-based API 的返回转换成 AsrClient 的同构格式（毫秒时间戳）
    def parse_sentences(output)
      raw_sentences = []

      if output['results'].is_a?(Array) && output['results'].first
        transcription = fetch_transcription(output['results'].first['transcription_url'])
        (transcription['transcripts'] || []).each do |tr|
          raw_sentences.concat(tr['sentences'] || [])
        end
      elsif output['transcripts'].is_a?(Array)
        output['transcripts'].each do |tr|
          raw_sentences.concat(tr['sentences'] || [])
        end
      end

      raw_sentences.each_with_index.map do |s, i|
        words = (s['words'] || []).map do |w|
          word = {
            'text' => w['text'].to_s,
            'begin_time' => to_ms(w['begin_time']),
            'end_time' => to_ms(w['end_time'])
          }
          word['punctuation'] = w['punctuation'] if w.key?('punctuation')
          word
        end

        {
          'sentence_id' => i,
          'text' => s['text'].to_s,
          'begin_time' => to_ms(s['begin_time']),
          'end_time' => to_ms(s['end_time']),
          'words' => words
        }
      end
    end

    def fetch_transcription(url)
      response = HTTParty.get(url)
      raise Error, "下载转写结果失败: #{response.code}" unless response.success?

      JSON.parse(response.body)
    end

    # paraformer-v2 返回的时间戳已是毫秒
    def to_ms(value)
      return 0 if value.nil?

      value.to_i
    end

    def headers
      { 'Authorization' => "Bearer #{@api_key}", 'Content-Type' => 'application/json' }
    end
  end
end
