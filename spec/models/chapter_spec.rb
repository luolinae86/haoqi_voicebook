# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chapter, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:book) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:sort_order) }
    it { is_expected.to validate_numericality_of(:word_count).is_greater_than_or_equal_to(0).allow_nil }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 sort_order 升序排列" do
        book = create(:book)
        ch3 = create(:chapter, book: book, sort_order: 3)
        ch1 = create(:chapter, book: book, sort_order: 1)
        ch2 = create(:chapter, book: book, sort_order: 2)

        expect(book.chapters.ordered).to eq([ch1, ch2, ch3])
      end
    end

    describe ".free_chapters" do
      it "只返回免费章节" do
        book = create(:book)
        free_ch = create(:chapter, book: book, is_free: true)
        vip_ch = create(:chapter, book: book, is_free: false)

        expect(Chapter.free_chapters).to include(free_ch)
        expect(Chapter.free_chapters).not_to include(vip_ch)
      end
    end

    describe ".vip_chapters" do
      it "只返回 VIP 章节" do
        book = create(:book)
        vip_ch = create(:chapter, book: book, is_vip: true)
        free_ch = create(:chapter, book: book, is_vip: false)

        expect(Chapter.vip_chapters).to include(vip_ch)
        expect(Chapter.vip_chapters).not_to include(free_ch)
      end
    end
  end
end
