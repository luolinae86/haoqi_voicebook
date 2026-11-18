# frozen_string_literal: true

require 'httparty'
require 'json'

module DashScope
  # 用 Qwen 大模型修正中文文本中的标点符号错误。
  # 包括：错误的标点（，→。或。→，）、缺失的标点、多余的标点。
  class PunctuationCorrector
    class Error < StandardError; end

    API_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'
    MODEL = 'qwen-plus'

    SYSTEM_PROMPT = <<~PROMPT.chomp
      你是一个中文标点符号纠错专家。请修正以下中文文本中的标点符号错误。

      规则：
      1. 修正错误的标点符号（如该用逗号的地方用了句号，该用句号的地方用了逗号）
      2. 在缺失标点的地方添加正确的标点符号
      3. 删除多余的标点符号
      4. 不要修改任何汉字，只修改标点符号
      5. 保持原文的措辞和语序不变

      直接输出修正后的文本，不要有任何解释或额外内容。
    PROMPT

    def initialize(api_key: ENV['DASHSCOPE_API_KEY'])
      @api_key = api_key
    end

    def correct(text)
      return text if text.blank?

      response = HTTParty.post(
        API_URL,
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: MODEL,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: text }
          ]
        }.to_json,
        timeout: 30
      )

      raise Error, "LLM 标点纠错失败: #{response.code}" unless response.success?

      result = JSON.parse(response.body)
      corrected = result.dig('choices', 0, 'message', 'content')&.strip
      corrected.presence || text
    rescue StandardError => e
      Rails.logger.warn("[PunctuationCorrector] 纠错失败，使用原文: #{e.message}")
      text
    end
  end
end
