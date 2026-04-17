# frozen_string_literal: true

require "rails_helper"

RSpec.describe Book, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:category).optional }
    it { should belong_to(:grade).optional }
    it { should have_many(:chapters).dependent(:destroy) }
    it { should have_one(:audio_album).dependent(:destroy) }
    it { should have_many(:collection_items).dependent(:destroy) }
    it { should have_many(:collections).through(:collection_items) }
    it { should have_many(:bookshelves).dependent(:destroy) }
    it { should have_many(:reading_records).dependent(:destroy) }
    it { should have_many(:bookmarks).dependent(:destroy) }
    it { should have_many(:ranking_items).dependent(:destroy) }
    it { should have_many(:recommendation_items).dependent(:destroy) }
    it { should have_many(:blacklisted_books).dependent(:destroy) }
  end

  # 验证测试
  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content_type) }
    it { should validate_numericality_of(:play_count).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:word_count).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:rating).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(10).allow_nil }
  end

  # 枚举测试
  describe "enums" do
    it { should define_enum_for(:content_type).with_values(ebook: 0, audio: 1, video: 2, picture_book: 3) }
    it { should define_enum_for(:status).with_values(draft: 0, published: 1, offline: 2) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".published_books" do
      it "只返回已发布的图书" do
        published = create(:book, status: :published)
        draft = create(:book, status: :draft)

        expect(Book.published_books).to include(published)
        expect(Book.published_books).not_to include(draft)
      end
    end

    describe ".free_books" do
      it "只返回免费图书" do
        free_book = create(:book, is_free: true)
        paid_book = create(:book, is_free: false)

        expect(Book.free_books).to include(free_book)
        expect(Book.free_books).not_to include(paid_book)
      end
    end

    describe ".vip_books" do
      it "只返回 VIP 图书" do
        vip_book = create(:book, is_vip: true)
        normal_book = create(:book, is_vip: false)

        expect(Book.vip_books).to include(vip_book)
        expect(Book.vip_books).not_to include(normal_book)
      end
    end

    describe ".by_type" do
      it "按内容类型筛选" do
        ebook = create(:book, content_type: :ebook)
        audio = create(:book, content_type: :audio)

        expect(Book.by_type(:ebook)).to include(ebook)
        expect(Book.by_type(:ebook)).not_to include(audio)
      end
    end

    describe ".by_category" do
      it "按分类筛选" do
        category = create(:category)
        book_in_cat = create(:book, category: category)
        book_other = create(:book)

        expect(Book.by_category(category.id)).to include(book_in_cat)
        expect(Book.by_category(category.id)).not_to include(book_other)
      end
    end

    describe ".by_grade" do
      it "按年级筛选" do
        grade = create(:grade)
        book_in_grade = create(:book, grade: grade)
        book_other = create(:book)

        expect(Book.by_grade(grade.id)).to include(book_in_grade)
        expect(Book.by_grade(grade.id)).not_to include(book_other)
      end
    end

    describe ".popular" do
      it "按播放次数降序排列" do
        book_low = create(:book, play_count: 10)
        book_high = create(:book, play_count: 100)

        expect(Book.popular.first).to eq(book_high)
      end
    end

    describe ".highest_rated" do
      it "按评分降序排列" do
        book_low = create(:book, rating: 5.0)
        book_high = create(:book, rating: 9.5)

        expect(Book.highest_rated.first).to eq(book_high)
      end
    end

    describe ".recently_added" do
      it "按创建时间降序排列" do
        old_book = create(:book, created_at: 1.week.ago)
        new_book = create(:book, created_at: 1.hour.ago)

        expect(Book.recently_added.first).to eq(new_book)
      end
    end
  end
end
