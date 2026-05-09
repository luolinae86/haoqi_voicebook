# frozen_string_literal: true

# 图书工厂
FactoryBot.define do
  factory :book do
    name { Faker::Book.title }
    cover_image_url { Faker::Internet.url(host: "cdn.example.com", path: "/covers/#{SecureRandom.hex(4)}.jpg") }
    themes { ["冒险", "成长"] }
    status { :published }
    content_type { :ebook }

    # 关联
    association :category
    association :supplier

    trait :with_author do
      association :author
    end

    trait :with_level do
      association :book_level
    end
  end
end
