# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bookshelf, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:app_user) }
    it { should belong_to(:book) }
    it { should belong_to(:last_read_chapter).class_name("Chapter").optional }
  end

  # 验证测试
  describe "validations" do
    subject { create(:bookshelf) }

    it { should validate_uniqueness_of(:app_user_id).scoped_to(:book_id).with_message("该图书已在书架中") }
    it { should validate_numericality_of(:reading_progress).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100).allow_nil }
  end

  # 作用域测试
  describe "scopes" do
    describe ".recently_read" do
      it "按最后阅读时间降序排列" do
        app_user = create(:app_user)
        old_shelf = create(:bookshelf, app_user: app_user, last_read_at: 1.week.ago)
        new_shelf = create(:bookshelf, app_user: app_user, last_read_at: 1.hour.ago)

        expect(app_user.bookshelves.recently_read.first).to eq(new_shelf)
      end
    end
  end

  # 实例方法测试
  describe "#update_progress!" do
    it "更新阅读进度和最后阅读时间" do
      bookshelf = create(:bookshelf, reading_progress: 10)
      bookshelf.update_progress!(progress: 50)

      expect(bookshelf.reading_progress).to eq(50)
      expect(bookshelf.last_read_at).to be_present
    end

    it "同时更新最后阅读章节" do
      book = create(:book)
      chapter = create(:chapter, book: book)
      bookshelf = create(:bookshelf, book: book)

      bookshelf.update_progress!(progress: 30, chapter: chapter)

      expect(bookshelf.last_read_chapter).to eq(chapter)
    end
  end
end
