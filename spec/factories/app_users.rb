# frozen_string_literal: true

# App用户工厂
# == Schema Information
#
# Table name: app_users(用户表)
#
#  id                                 :bigint           not null, primary key
#  avatar(头像URL)                    :string(255)
#  books_read(读过的书(本))           :integer          default(0), not null
#  is_vip(是否VIP)                    :boolean          default(FALSE), not null
#  nickname(昵称)                     :string(255)
#  password_digest(加密密码)          :string(255)
#  phone(手机号)                      :string(255)
#  qq_openid(QQ openid)               :string(255)
#  reading_minutes(阅读时长(分钟))    :integer          default(0), not null
#  reading_words(阅读字数)            :integer          default(0), not null
#  role(角色：0-孩子 1-家长 2-管理员) :integer          default("child"), not null
#  uuid                               :string(255)      not null
#  vip_expires_at(VIP过期时间)        :datetime
#  wechat_openid(微信openid)          :string(255)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  device_id                          :string(64)
#  grade_id(年级ID)                   :bigint
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
FactoryBot.define do
  factory :app_user, class: "AppUser" do
    phone { "1#{rand(3..9)}#{Faker::Number.number(digits: 9)}" }
    nickname { Faker::Internet.username }
    password { "password123" }
    role { :child }
    is_vip { false }
    vip_expires_at { nil }
    reading_words { 0 }
    reading_minutes { 0 }
    books_read { 0 }

    after(:create) do |user|
      # 为每个用户创建一个默认设备
      create(:device, app_user: user) unless user.devices.any?
    end

    # 管理员
    trait :admin do
      role { :admin }
    end

    # VIP用户
    trait :vip do
      is_vip { true }
      vip_expires_at { 30.days.from_now }
    end

    # VIP已过期
    trait :vip_expired do
      is_vip { true }
      vip_expires_at { 1.day.ago }
    end

    # 有阅读记录的用户
    trait :with_reading_stats do
      reading_words { Faker::Number.between(from: 1000, to: 100_000) }
      reading_minutes { Faker::Number.between(from: 60, to: 5000) }
      books_read { Faker::Number.between(from: 1, to: 50) }
    end
  end

  factory :device do
    sequence(:device_id) { |n| "device_#{n}_#{SecureRandom.hex(16)}" }
    app_user
  end
end
