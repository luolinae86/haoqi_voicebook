# frozen_string_literal: true

require 'socket'
require 'openssl'
require 'uri'
require 'json'
require 'securerandom'
require 'websocket/driver'

module PictureBook
  # DashScope 实时语音识别(paraformer-realtime-v2)的 WebSocket 客户端。
  # 只走实时口:文件转写接口给出的字级时间是按句匀速铺出来的(实测 R²=1),
  # 撑不起逐字高亮,也定不出翻页切点;实时口的词时间才是声学对齐的。
  class AsrClient
    URL = 'wss://dashscope.aliyuncs.com/api-ws/v1/inference'
    MODEL = 'paraformer-realtime-v2'
    FRAME_BYTES = 3_200 # 16k/16bit/单声道 的 100ms
    # 帧间隔。实测:0.01(≈10× 实时)服务端一句结果都不回,0.05(≈2×)正常出词时间,
    # 所以这里守住 2× 上限,别为了快把识别跑成空。
    SEND_INTERVAL = 0.05
    READ_TIMEOUT = 30.0

    class Error < StandardError; end

    def initialize(api_key:, model: MODEL, sample_rate: 16_000, format: 'mp3',
                   timestamp_alignment: true, disfluency_removal: false)
      @api_key = api_key
      @model = model
      @sample_rate = sample_rate
      @format = format
      @timestamp_alignment = timestamp_alignment
      @disfluency_removal = disfluency_removal
    end

    # @return [Array<Hash>] 最终句子(按 sentence_id 排序),各带 begin_time/end_time/text/words
    def transcribe(audio_path)
      @task_id = SecureRandom.uuid
      @sentences = {}
      @open = false
      @started = false
      @finished = false
      @failure = nil

      @conn = Connection.new(URL)
      driver = WebSocket::Driver.client(@conn)
      driver.headers['Authorization'] = "Bearer #{@api_key}"
      driver.headers['X-DashScope-DataInspection'] = 'enable'
      driver.on('message') { |event| handle_frame(event.data) }
      driver.on('open') { @open = true }
      driver.on('close') { @finished = true }
      driver.on('error') { |event| @failure ||= event.message }
      @driver = driver
      driver.start

      await { @open || @failure }
      raise Error, "WebSocket 握手失败: #{@failure}" if @failure

      driver.text(run_frame)
      await { @started || @failure }
      raise Error, "建任务失败: #{@failure}" if @failure

      stream_audio(audio_path)
      driver.text(finish_frame)
      await { @finished || @failure }
      raise Error, "识别失败: #{@failure}" if @failure

      @conn.close
      @sentences.values.sort_by { |s| s['sentence_id'].to_i }
    end

    private

    def run_frame
      JSON.dump(
        header: { action: 'run-task', task_id: @task_id, streaming: 'duplex' },
        payload: {
          task_group: 'audio', task: 'asr', function: 'recognition', model: @model,
          parameters: {
            format: @format,
            sample_rate: @sample_rate,
            disfluency_removal_enabled: @disfluency_removal,
            timestamp_alignment_enabled: @timestamp_alignment
          },
          input: {}
        }
      )
    end

    def finish_frame
      JSON.dump(header: { action: 'finish-task', task_id: @task_id, streaming: 'duplex' },
                payload: { input: {} })
    end

    def stream_audio(path)
      File.open(path, 'rb') do |file|
        while (chunk = file.read(FRAME_BYTES))
          @driver.binary(chunk)
          pump
          sleep SEND_INTERVAL
        end
      end
    end

    def handle_frame(data)
      msg = JSON.parse(data)
    rescue JSON::ParserError
      nil
    else
      event = msg.dig('header', 'event')
      sentence = msg.dig('payload', 'output', 'sentence')
      # 同一个 sentence_id 会被中间结果反复覆盖,只留带 words 的最后一版
      @sentences[sentence['sentence_id']] = sentence if event == 'result-generated' && sentence.is_a?(Hash) && sentence['words']

      case event
      when 'task-started' then @started = true
      when 'task-finished' then @finished = true
      when 'task-failed' then @failure = "#{msg.dig('header', 'error_code')} #{msg.dig('header', 'error_message')}"
      end
    end

    def pump
      while (data = @conn.read_nonblock_safe)
        @driver.parse(data)
      end
    end

    def await
      # 单调钟：读 socket 的超时不该被系统改时间/时区影响
      clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      deadline = clock.call + READ_TIMEOUT
      until yield
        raise Error, "等待服务端响应超时(#{READ_TIMEOUT}s)" if clock.call > deadline

        pump
        sleep 0.01
      end
    end

    # websocket-driver 的 client 要求 socket 对象能回 url、能 write
    class Connection
      attr_reader :url

      def initialize(url)
        @url = url
        uri = URI.parse(url)
        tcp = TCPSocket.new(uri.host, uri.port || 443)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
        @io = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
        @io.hostname = uri.host
        @io.sync_close = true
        @io.connect
      end

      delegate :write, to: :@io

      def read_nonblock_safe
        data = @io.read_nonblock(16_384, exception: false)
        data == :wait_readable ? nil : data
      rescue EOFError
        nil
      end

      def close
        @io.close
      rescue IOError
        nil
      end
    end
  end
end
