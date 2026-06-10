# frozen_string_literal: true

# == Schema Information
#
# Table name: app_users(用户表)
#
#  id                                                :bigint           not null, primary key
#  books_read(读过的书(本))                          :integer          default(0), not null
#  channel(注册渠道：app_store/tablet/community/koc) :string(32)
#  is_vip(是否VIP)                                   :boolean          default(FALSE), not null
#  nickname(昵称)                                    :string(255)
#  password_digest(加密密码)                         :string(255)
#  phone(手机号)                                     :string(255)
#  qq_openid(QQ openid)                              :string(255)
#  reading_minutes(阅读时长(分钟))                   :integer          default(0), not null
#  reading_words(阅读字数)                           :integer          default(0), not null
#  role(角色：0-孩子 1-家长 2-管理员)                :integer          default("child"), not null
#  uuid                                              :string(255)      not null
#  vip_expires_at(VIP过期时间)                       :datetime
#  wechat_nickname(微信昵称)                         :string(255)
#  wechat_openid(微信openid)                         :string(255)
#  created_at                                        :datetime         not null
#  updated_at                                        :datetime         not null
#  device_id                                         :string(64)
#  grade_id(年级ID)                                  :bigint
#  head_img_id(用户头像ID)                           :bigint
#
# Indexes
#
#  index_app_users_on_device_id      (device_id) UNIQUE
#  index_app_users_on_grade_id       (grade_id)
#  index_app_users_on_is_vip         (is_vip)
#  index_app_users_on_phone          (phone) UNIQUE
#  index_app_users_on_qq_openid      (qq_openid) UNIQUE
#  index_app_users_on_uuid           (uuid) UNIQUE
#  index_app_users_on_wechat_openid  (wechat_openid) UNIQUE
#
require "rails_helper"

RSpec.describe AppUser, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to have_many(:bookshelves).dependent(:destroy) }
    it { is_expected.to have_many(:shelf_books).through(:bookshelves).source(:book) }
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

  describe "#expire_cache" do
    it "更新用户属性后清除缓存" do
      user = create(:app_user, nickname: "old")
      cache_key = "app_user_#{user.uuid}"
      expect(Rails.cache).to receive(:delete).with(cache_key)

      user.update!(nickname: "new")
    end

    it "创建用户时不清除缓存（仅 update 触发）" do
      allow(Rails.cache).to receive(:delete)
      expect(Rails.cache).not_to receive(:delete)
      create(:app_user)
    end

    it "删除用户时不清除缓存（仅 update 触发）" do
      user = create(:app_user)
      allow(Rails.cache).to receive(:delete)
      expect(Rails.cache).not_to receive(:delete)

      user.destroy
    end
  end
end
