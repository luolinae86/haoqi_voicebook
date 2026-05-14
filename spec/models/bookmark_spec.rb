# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmarks
#
#  id                  :bigint           not null, primary key
#  position(位置(%))   :decimal(5, 2)    default(0.0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  app_user_id(用户ID) :integer          not null
#  book_id(图书ID)     :integer          not null
#  chapter_id(章节ID)  :integer
#
# Indexes
#
#  index_bookmarks_on_app_user_id  (app_user_id)
#  index_bookmarks_on_book_id      (book_id)
#
require "rails_helper"

RSpec.describe Bookmark, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:app_user) }
    it { is_expected.to belong_to(:book) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0).allow_nil }
  end

  # 作用域测试
  describe "scopes" do
    describe ".recent" do
      it "按创建时间降序排列" do
        app_user = create(:app_user)
        book = create(:book)
        create(:bookmark, app_user: app_user, book: book, created_at: 1.week.ago)
        new_bookmark = create(:bookmark, app_user: app_user, book: book, created_at: 1.hour.ago)

        expect(Bookmark.recent.first).to eq(new_bookmark)
      end
    end
  end
end
