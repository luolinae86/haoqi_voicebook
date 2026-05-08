# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppUser, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:grade).optional }
    it { is_expected.to have_many(:bookshelves).dependent(:destroy) }
    it { is_expected.to have_many(:shelf_books).through(:bookshelves).source(:book) }
    it { is_expected.to have_many(:reading_records).dependent(:destroy) }
    it { is_expected.to have_many(:memberships).dependent(:destroy) }
    it { is_expected.to have_many(:orders).dependent(:destroy) }
    it { is_expected.to have_many(:bookmarks).dependent(:destroy) }
    it { is_expected.to have_one(:parental_control).dependent(:destroy) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:app_user) }

    it { is_expected.to validate_uniqueness_of(:phone).case_insensitive }
    it { is_expected.to allow_value(nil).for(:phone) }
    it { is_expected.to allow_value("").for(:phone) }
    it { is_expected.to allow_value("13800138000").for(:phone) }
    it { is_expected.to allow_value("19912345678").for(:phone) }
    it { is_expected.not_to allow_value("12345678901").for(:phone) }
    it { is_expected.not_to allow_value("1380013800").for(:phone) }
    it { is_expected.not_to allow_value("abc").for(:phone) }
    it { is_expected.to validate_length_of(:nickname).is_at_most(50) }
  end

  # 枚举测试
  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(child: 0, parent: 1, admin: 2) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".vip_users" do
      it "只返回有效的 VIP 用户" do
        vip_user = create(:app_user, is_vip: true, vip_expires_at: 1.month.from_now)
        expired_vip = create(:app_user, is_vip: true, vip_expires_at: 1.day.ago)
        normal_user = create(:app_user, is_vip: false)

        expect(AppUser.vip_users).to include(vip_user)
        expect(AppUser.vip_users).not_to include(expired_vip)
        expect(AppUser.vip_users).not_to include(normal_user)
      end
    end
  end

  # 实例方法测试
  describe "#vip_active?" do
    it "当用户是 VIP 且未过期时返回 true" do
      user = create(:app_user, is_vip: true, vip_expires_at: 1.month.from_now)
      expect(user.vip_active?).to be true
    end

    it "当 VIP 已过期时返回 false" do
      user = create(:app_user, is_vip: true, vip_expires_at: 1.day.ago)
      expect(user.vip_active?).to be false
    end

    it "当用户不是 VIP 时返回 false" do
      user = create(:app_user, is_vip: false)
      expect(user.vip_active?).to be false
    end
  end

  describe "#update_reading_stats!" do
    it "增加阅读字数统计" do
      user = create(:app_user, reading_words: 100)
      user.update_reading_stats!(words: 50)
      expect(user.reload.reading_words).to eq(150)
    end

    it "增加阅读时长统计" do
      user = create(:app_user, reading_minutes: 10)
      user.update_reading_stats!(minutes: 5)
      expect(user.reload.reading_minutes).to eq(15)
    end

    it "增加阅读本数统计" do
      user = create(:app_user, books_read: 3)
      user.update_reading_stats!(books: 1)
      expect(user.reload.books_read).to eq(4)
    end

    it "参数为 0 时不更新" do
      user = create(:app_user, reading_words: 100)
      user.update_reading_stats!(words: 0, minutes: 0, books: 0)
      expect(user.reload.reading_words).to eq(100)
    end
  end
end
