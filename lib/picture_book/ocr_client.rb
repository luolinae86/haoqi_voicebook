# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'
require 'httparty'

module PictureBook
  # 页面文字识别。走阿里云百炼的 qwen-vl（HTTP 兼容口），不装本地 OCR：
  # ECS 上要跑通中文竖排/装饰字，tesseract 那套装起来又准不了，一张图一次调用几分钱。
  # 原始返回一定要留着（ocr_raw），重试和人工校对都靠它，别再花一次钱。
  class OcrClient
    URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'
    # 这个百炼账号只开了 qwen3-vl-plus / qwen-vl-ocr 一线;qwen-vl-max 会 403 access_denied。
    # qwen-vl-ocr 会把出版社、绘者、页码全倒出来,qwen3-vl-plus 认指令,只给正文行。
    MODEL = 'qwen3-vl-plus'
    TIMEOUT = 120

    class Error < StandardError; end
    # 网络抖、限流、5xx 都算可重试；401/403/参数错直接抛，重试也白搭
    class Retryable < Error; end

    RETRIES = 3

    PROMPT = <<~TEXT
      这是一本中文儿童绘本的一页。只提取正文故事文字，按阅读顺序逐行输出。
      规则：
      1. 汉字上方标注的拼音不要输出。
      2. 页码、出版社名、书脊上的书名、封面装饰字、对话框之外的说明文字不要输出。
      3. 每行原文单独一行，不要合并、不要改写、不要解释。
      4. 原文里的标点一个都不能少，尤其是行末的句号「。」和问号「？」，照抄。
      5. 只输出行文本本身，不要编号、不要引号、不要前后说明。
    TEXT

    # key 到调用时才取：重跑已经落库的 OCR 不该因为没有环境变量而炸
    def initialize(api_key: nil, model: MODEL)
      @api_key = api_key
      @model = model
    end

    # image_or_url: 本地图片路径，或公网/OSS 可访问的图片 URL
    # 返回 { "lines" => [...], "text" => 原始返回, "request_id" => ..., "usage" => ... }
    def call(image_or_url)
      attempts = 0
      begin
        attempts += 1
        post(image_or_url)
      # httparty 0.24 没有 HTTParty::TimeoutError，超时就是从 Net::/Errno:: 里冒出来的；
      # EOFError 不单列，它就是 IOError 的子类
      rescue Retryable, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT,
             OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout,
             IOError => e
        raise Error, "qwen-vl 调用失败(重试 #{attempts} 次): #{e.message}" if attempts >= RETRIES

        sleep(attempts * 2)
        retry
      end
    end

    private

    def post(image_or_url)
      response = HTTParty.post(
        URL,
        headers: {
          'Authorization' => "Bearer #{@api_key || ENV.fetch('DASHSCOPE_API_KEY')}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: @model,
          messages: [{ role: 'user', content: [image_content(image_or_url), { 'type' => 'text', 'text' => PROMPT }] }],
          temperature: 0.01,
          max_tokens: 1_024
        }.to_json,
        timeout: TIMEOUT
      )

      raise Retryable, "HTTP #{response.code}: #{response.body.to_s[0, 200]}" if response.code >= 429
      raise Error, "HTTP #{response.code}: #{response.body.to_s[0, 300]}" unless response.success?

      body = JSON.parse(response.body.to_s)
      choices = body['choices'] || []
      content = choices.dig(0, 'message', 'content').to_s
      raise Error, "qwen-vl 没有返回内容: #{body.inspect[0, 300]}" if content.strip.empty?

      {
        'lines' => parse_lines(content),
        'text' => content,
        'request_id' => body['id'],
        'usage' => body['usage']
      }
    end

    # 模型偶尔还是会给行加 "1. " 或引号，这里兜一层
    def parse_lines(content)
      content.to_s.split(/\r?\n/).map do |line|
        line.strip
            .sub(/\A[-*·]\s*/, '')
            .sub(/\A\d+[.、)]\s*/, '')
            .delete_prefix('「').delete_suffix('」')
            .delete_prefix('“').delete_suffix('”')
      end.reject(&:empty?)
    end

    def image_content(image_or_url)
      if image_or_url.is_a?(String) && image_or_url.match?(%r{\Ahttps?://})
        { 'type' => 'image_url', 'image_url' => { 'url' => image_or_url } }
      else
        {
          'type' => 'image_url',
          'image_url' => { 'url' => "data:#{mime_type(image_or_url)};base64,#{Base64.strict_encode64(File.binread(image_or_url))}" }
        }
      end
    end

    def mime_type(path)
      case File.extname(path.to_s).downcase
      when '.png' then 'image/png'
      when '.webp' then 'image/webp'
      else 'image/jpeg'
      end
    end
  end
end
