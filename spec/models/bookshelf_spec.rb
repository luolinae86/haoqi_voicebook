# frozen_string_literal: true

# == Schema Information
#
# Table name: bookshelves(书架表)
#
#  id                                   :bigint           not null, primary key
#  last_read_at(最后阅读时间)           :datetime
#  reading_progress(阅读进度(%))        :decimal(5, 2)    default(0.0)
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  app_user_id(用户ID)                  :integer          not null
#  book_id(图书ID)                      :bigint           not null
#  last_read_chapter_id(最后阅读章节ID) :bigint
#
# Indexes
#
#  index_bookshelves_on_app_user_id              (app_user_id)
#  index_bookshelves_on_app_user_id_and_book_id  (app_user_id,book_id) UNIQUE
#  index_bookshelves_on_book_id                  (book_id)
#
require "rails_helper"

RSpec.describe Bookshelf, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:app_user) }
    it { is_expected.to belong_to(:book) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:bookshelf) }

    it { is_expected.to validate_uniqueness_of(:app_user_id).scoped_to(:book_id).with_message("该图书已在书架中") }
    it { is_expected.to validate_numericality_of(:reading_progress).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100).allow_nil }
  end

  # 作用域测试
  describe "scopes" do
    describe ".recently_read" do
      it "按最后阅读时间降序排列" do
        app_user = create(:app_user)
        create(:bookshelf, app_user: app_user, last_read_at: 1.week.ago)
        new_shelf = create(:bookshelf, app_user: app_user, last_read_at: 1.hour.ago)

        expect(app_user.bookshelves.recently_read.first).to eq(new_shelf)
      end
    end
  end

  # 实例方法测试
  describe "reading progress" do
    it "更新阅读进度和最后阅读时间" do
      bookshelf = create(:bookshelf, reading_progress: 10)
      bookshelf.update!(reading_progress: 50, last_read_at: Time.current)

      expect(bookshelf.reading_progress).to eq(50)
      expect(bookshelf.last_read_at).to be_present
    end
  end
end
