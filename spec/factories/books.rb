# frozen_string_literal: true

# 图书工厂
# == Schema Information
#
# Table name: books
#
#  id                                                                   :bigint           not null, primary key
#  compilations                                                         :bigint
#  content_description                                                  :text(65535)
#  content_file_name(内容文件名)                                        :string(255)
#  content_file_type(内容文件类型 (epub/pdf))                           :string(255)
#  content_file_url(电子书内容文件URL)                                  :string(255)
#  content_type(类型：0-电子书 1-有声 2-视频 3-绘本)                    :integer          default("ebook"), not null
#  cover_image_url(绘本封面URL)                                         :string(255)
#  ebook_checksum(源 PDF 校验值)                                        :string(255)
#  epub_export_error(EPUB 导出失败原因)                                 :text(65535)
#  epub_export_status(EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败) :integer          default("not_exported")
#  epub_oss_key(EPUB 文件 OSS 路径)                                     :string(255)
#  epub_oss_url(EPUB 文件公网 URL)                                      :string(255)
#  import_error_message(导入失败信息)                                   :text(65535)
#  import_status(电子书导入状态)                                        :integer          default("not_imported"), not null
#  imported_at(导入完成时间)                                            :datetime
#  is_free(是否免费)                                                    :boolean          default(FALSE), not null
#  is_vip(是否VIP)                                                      :boolean          default(FALSE), not null
#  isbn(ISBN)                                                           :string(255)
#  name(绘本名称)                                                       :string(255)      not null
#  nav_oss_url(nav.xhtml 的 OSS URL)                                    :string(255)
#  page_count(电子书总页数)                                             :integer          default(0), not null
#  play_count(播放/阅读次数)                                            :integer          default(0), not null
#  rating(评分)                                                         :decimal(3, 1)    default(0.0)
#  source_pdf_filename(源 PDF 文件名)                                   :string(255)
#  source_pdf_path(源 PDF 存储路径)                                     :string(255)
#  status(状态：0-草稿 1-已发布 2-已下架)                               :integer          default("draft"), not null
#  styles_oss_url(book.css 的 OSS URL)                                  :string(255)
#  themes(主题)                                                         :json
#  word_count(字数)                                                     :integer          default(0), not null
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  author_id                                                            :bigint
#  book_level_id                                                        :bigint
#  category_id(绘本类型)                                                :bigint
#  grade_id(年级ID)                                                     :bigint
#  supplier_id(归属供应商)                                              :bigint
#
# Indexes
#
#  index_books_on_category_id    (category_id)
#  index_books_on_import_status  (import_status)
#  index_books_on_name           (name)
#  index_books_on_status         (status)
#  index_books_on_supplier_id    (supplier_id)
#
# Foreign Keys
#
#  fk_rails_...  (supplier_id => suppliers.id)
#
FactoryBot.define do
  factory :book do
    name { Faker::Book.title }
    cover_image_url { Faker::Internet.url(host: "cdn.example.com", path: "/covers/#{SecureRandom.hex(4)}.jpg") }
    themes { ["冒险", "成长"] }
    status { :published }
    content_type { :ebook }

    # 关联
    association :category
    association :supplier

    trait :with_author do
      association :author
    end

    trait :with_level do
      association :book_level
    end
  end
end
