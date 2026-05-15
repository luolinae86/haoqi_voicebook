# frozen_string_literal: true

# == Schema Information
#
# Table name: ebook_pages(电子书页面表)
#
#  id                             :bigint           not null, primary key
#  page_number(页码)              :integer          not null
#  image_url(页面图片URL)         :string(255)
#  xhtml_content(页面 XHTML 内容) :text(65535)
#  word_count(字数)               :integer          default(0), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  book_id(图书ID)                :bigint           not null
#
# Indexes
#
#  index_ebook_pages_on_book_id                  (book_id)
#  index_ebook_pages_on_book_id_and_page_number  (book_id,page_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
FactoryBot.define do
  factory :ebook_page do
    association :book
    sequence(:page_number) { |n| n }
    word_count { 8 }

    trait :pdf_image do
      image_url { "https://bucket.oss-cn-beijing.aliyuncs.com/test/page-1.png" }
      word_count { 0 }
    end

    trait :epub do
      xhtml_content { "<html><body><p>这是示例页面内容</p></body></html>" }
      word_count { 10 }
    end
  end
end
