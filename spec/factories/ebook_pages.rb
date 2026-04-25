# frozen_string_literal: true

FactoryBot.define do
  factory :ebook_page do
    association :book
    sequence(:page_number) { |n| n }
    page_width { 428.0 }
    page_height { 612.0 }
    plain_text { "[BODY] 这是示例页面内容\n" }
    rich_content do
      {
        text: "[BODY] 这是示例页面内容\n",
        lines: [
          {
            id: "line-1",
            role: "body",
            text: "这是示例页面内容",
            marker: "[BODY]",
            text_with_role: "[BODY] 这是示例页面内容\n",
            bbox: { left: 48.0, bottom: 480.0, width: 220.0, height: 18.0, right: 268.0, top: 498.0 }
          }
        ],
        images: []
      }
    end
    word_count { 8 }
    block_count { 1 }
    image_count { 0 }
  end
end
