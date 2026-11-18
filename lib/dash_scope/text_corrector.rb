# frozen_string_literal: true

require 'httparty'
require 'json'

module DashScope
  # 用 Qwen 大模型修正 ASR 文本中的同音错别字。
  class TextCorrector
    class Error < StandardError; end

    API_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions'
    MODEL = 'qwen-plus'

    SYSTEM_PROMPT = <<~PROMPT.chomp
      你是一个语音识别纠错专家。请修正以下中文文本中因语音识别产生的同音错别字。

      输入文本是纯汉字，不含标点符号。

      严格规则：
      1. 只替换同音或近音的错别字
      2. 不要增删任何字符，输出长度必须与输入完全相同
      3. 不要添加标点符号
      4. 不要改变措辞或语序
      5. 如果文本没有错误，原样输出

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

      raise Error, "LLM 纠错失败: #{response.code}" unless response.success?

      result = JSON.parse(response.body)
      corrected = result.dig('choices', 0, 'message', 'content')&.strip

      # 验证输出长度必须与输入相同（LLM 有时会违反规则增删字符）
      if corrected.present? && corrected.length == text.length
        corrected
      else
        Rails.logger.warn("[TextCorrector] LLM 输出长度不匹配 (输入: #{text.length}, 输出: #{corrected&.length || 0})，使用原文")
        text
      end
    rescue StandardError => e
      Rails.logger.warn("[TextCorrector] 纠错失败，使用原文: #{e.message}")
      text
    end
  end
end
