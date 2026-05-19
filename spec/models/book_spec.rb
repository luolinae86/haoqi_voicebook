# frozen_string_literal: true

# == Schema Information
#
# Table name: books
#
#  id                                                                   :bigint           not null, primary key
#  compilations                                                         :bigint
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
require "rails_helper"

RSpec.describe Book, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:supplier).optional }
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to belong_to(:author).optional }
    it { is_expected.to have_and_belong_to_many(:grades) }
    it { is_expected.to have_and_belong_to_many(:compilations) }
    it { is_expected.to have_and_belong_to_many(:category_subs) }
    it { is_expected.to have_many(:contents) }
    it { is_expected.to have_many(:bookshelves).dependent(:destroy) }
    it { is_expected.to have_many(:bookmarks).dependent(:destroy) }
    it { is_expected.to have_many(:blacklisted_books).dependent(:destroy) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "限制 name 最长 100 字符" do
      book = build(:book, name: "a" * 101)
      expect(book).not_to be_valid
    end

    it "允许 name 最长 100 字符" do
      book = build(:book, name: "a" * 100)
      expect(book).to be_valid
    end
  end

  # 实例方法测试
  describe "#themes_array" do
    it "返回 themes 数组" do
      book = build(:book, themes: ["冒险", "成长"])
      expect(book.themes_array).to eq(["冒险", "成长"])
    end

    it "themes 为 nil 时返回空数组" do
      book = build(:book, themes: nil)
      expect(book.themes_array).to eq([])
    end
  end

  # .sign_oss_url 方法测试
  describe ".sign_oss_url" do
    it "返回空值当 url 为空" do
      expect(Book.sign_oss_url(nil)).to be_nil
      expect(Book.sign_oss_url("")).to be_nil
      expect(Book.sign_oss_url("   ")).to be_nil
    end

    it "非 OSS 地址原样返回" do
      url = "https://example.com/image.png"
      expect(Book.sign_oss_url(url)).to eq(url)
    end

    it "生成带签名参数的 OSS URL" do
      url = "https://bucket.oss-cn-beijing.aliyuncs.com/test/page.png"
      signed = Book.sign_oss_url(url)
      expect(signed).to include("Expires=")
      expect(signed).to include("OSSAccessKeyId=")
      expect(signed).to include("Signature=")
    end

    it "中文路径也能正常生成签名 URL" do
      url = "https://zheli.oss-cn-beijing.aliyuncs.com/小老虎历险记/images/pages/1/image_1.png"
      signed = Book.sign_oss_url(url)
      expect(signed).to include("Expires=")
      expect(signed).to include("Signature=")
      # URL 路径应被编码
      expect(signed).to include("%E5%B0%8F")
    end
  end
end
