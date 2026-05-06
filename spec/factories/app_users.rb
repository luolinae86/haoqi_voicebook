# frozen_string_literal: true

# App用户工厂
FactoryBot.define do
  factory :app_user, class: "AppUser" do
    phone { "1#{rand(3..9)}#{Faker::Number.number(digits: 9)}" }
    nickname { Faker::Internet.username }
    avatar { Faker::Avatar.image }
    password { "password123" }
    role { :child }
    is_vip { false }
    vip_expires_at { nil }
    reading_words { 0 }
    reading_minutes { 0 }
    books_read { 0 }

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

    # 关联年级
    trait :with_grade do
      association :grade
    end
  end
end
