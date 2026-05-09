# frozen_string_literal: true

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
    it { is_expected.to have_many(:chapters) }
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
end