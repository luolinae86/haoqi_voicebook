# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bookmark, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:book) }
    it { should belong_to(:chapter).optional }
  end

  # 验证测试
  describe "validations" do
    it { should validate_numericality_of(:position).is_greater_than_or_equal_to(0).allow_nil }
  end

  # 作用域测试
  describe "scopes" do
    describe ".recent" do
      it "按创建时间降序排列" do
        user = create(:user)
        book = create(:book)
        old_bookmark = create(:bookmark, user: user, book: book, created_at: 1.week.ago)
        new_bookmark = create(:bookmark, user: user, book: book, created_at: 1.hour.ago)

        expect(Bookmark.recent.first).to eq(new_bookmark)
      end
    end
  end
end
