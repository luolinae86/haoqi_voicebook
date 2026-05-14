# frozen_string_literal: true

# == Schema Information
#
# Table name: ebook_pages(电子书页面表)
#
#  id                             :bigint           not null, primary key
#  block_count(块数量)            :integer          default(0), not null
#  image_count(图片数量)          :integer          default(0), not null
#  page_height(页面高度(pt))      :decimal(8, 2)    not null
#  page_number(页码)              :integer          not null
#  page_width(页面宽度(pt))       :decimal(8, 2)    not null
#  plain_text(页面纯文本)         :text(65535)
#  rich_content(页面富文本块)     :json             not null
#  word_count(字数)               :integer          default(0), not null
#  xhtml_content(页面 XHTML 内容) :text(65535)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  book_id(图书ID)                :bigint           not null
#  chapter_id                     :bigint
#
# Indexes
#
#  index_ebook_pages_on_book_id                  (book_id)
#  index_ebook_pages_on_book_id_and_page_number  (book_id,page_number) UNIQUE
#  index_ebook_pages_on_chapter_id               (chapter_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#  fk_rails_...  (chapter_id => chapters.id)
#
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
