# frozen_string_literal: true

# == Schema Information
#
# Table name: chapters(章节表（有声/视频章节）)
#
#  id                                              :bigint           not null, primary key
#  content_file_name(章节内容文件名)               :string(255)
#  content_file_type(内容文件类型 (mp3/mp4/wav等)) :string(255)
#  content_file_url(章节内容文件URL（音频/视频）)  :string(255)
#  cover_image_url(章节封面图片URL)                :string(255)
#  duration(音频/视频时长（秒）)                   :integer
#  is_free(是否免费)                               :boolean          default(FALSE)
#  is_published(是否已发布)                        :boolean          default(FALSE)
#  name(章节名称)                                  :string(255)      not null
#  publish_date(发布日期)                          :date
#  sn(排序)                                        :integer          default(0)
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  book_id(所属图书)                               :bigint           not null
#
# Indexes
#
#  index_chapters_on_book_id  (book_id)
#
FactoryBot.define do
  factory :chapter do
    association :book
    name { "第一章" }
    sn { 1 }
    is_free { false }
    is_published { true }
    content_file_type { "mp3" }
    content_file_url { "https://cdn.example.com/audio/chapter1.mp3" }
    content_file_name { "chapter1.mp3" }
    publish_date { nil }
  end
end
