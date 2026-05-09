# frozen_string_literal: true

# 图书工厂
FactoryBot.define do
  factory :book do
    title { Faker::Book.title }
    author { Faker::Book.author }
    publisher { Faker::Book.publisher }
    cover_image { Faker::Internet.url(host: "cdn.example.com", path: "/covers/#{SecureRandom.hex(4)}.jpg") }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    content_type { :ebook }
    isbn { Faker::Code.isbn }
    is_free { false }
    is_vip { false }
    play_count { 0 }
    word_count { Faker::Number.between(from: 1000, to: 100_000) }
    rating { Faker::Number.decimal(l_digits: 1, r_digits: 1) }
    status { :published }

    # 草稿状态
    trait :draft do
      status { :draft }
    end

    # 已下架
    trait :offline do
      status { :offline }
    end

    # 免费图书
    trait :free do
      is_free { true }
    end

    # VIP专享图书
    trait :vip_only do
      is_vip { true }
    end

    # 有声书
    trait :audio do
      content_type { :audio }
    end

    # 视频书
    trait :video do
      content_type { :video }
    end

    # 绘本
    trait :picture_book do
      content_type { :picture_book }
    end

    # 热门图书
    trait :popular do
      play_count { Faker::Number.between(from: 1000, to: 100_000) }
      rating { Faker::Number.between(from: 4.0, to: 5.0).round(1) }
    end
  end
end
