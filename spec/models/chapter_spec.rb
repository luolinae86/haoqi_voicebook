# frozen_string_literal: true

# == Schema Information
#
# Table name: chapters
#
#  id                                                                   :bigint           not null, primary key
#  content_file_name(章节内容文件名)                                    :string(255)
#  content_file_type(内容文件类型 (epub/pdf/txt))                       :string(255)
#  content_file_url(章节内容文件URL)                                    :string(255)
#  cover_image_url(章节封面图片URL)                                     :string(255)
#  epub_export_error(EPUB 导出失败原因)                                 :text(65535)
#  epub_export_status(EPUB 导出状态：0-未导出 1-导出中 2-已完成 3-失败) :integer          default("not_exported")
#  epub_oss_key(EPUB 文件 OSS 路径)                                     :string(255)
#  epub_oss_url(EPUB 文件公网 URL)                                      :string(255)
#  is_free(是否免费)                                                    :boolean          default(FALSE)
#  is_published(是否上线)                                               :boolean          default(FALSE)
#  name(章节名称)                                                       :string(255)      not null
#  nav_oss_url(nav.xhtml 的 OSS URL)                                    :string(255)
#  sn(排序)                                                             :integer          default(0)
#  styles_oss_url(book.css 的 OSS URL)                                  :string(255)
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  book_id(所属绘本)                                                    :bigint           not null
#
# Indexes
#
#  index_chapters_on_book_id  (book_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
require "rails_helper"

RSpec.describe Chapter, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:book) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "实例方法" do
    describe "#publish!" do
      it "将章节设为已发布" do
        chapter = create(:chapter, is_published: false)
        chapter.publish!
        expect(chapter.reload.is_published).to be true
      end
    end

    describe "#unpublish!" do
      it "将章节设为未发布" do
        chapter = create(:chapter, is_published: true)
        chapter.unpublish!
        expect(chapter.reload.is_published).to be false
      end
    end

    describe "#toggle_free" do
      it "切换免费状态" do
        chapter = create(:chapter, is_free: false)
        chapter.toggle_free
        expect(chapter.reload.is_free).to be true
      end
    end
  end
end
