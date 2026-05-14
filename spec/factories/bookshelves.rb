# frozen_string_literal: true

# 书架工厂
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
FactoryBot.define do
  factory :bookshelf do
    association :app_user
    association :book
    reading_progress { 0.0 }
    last_read_at { nil }

    # 阅读中
    trait :reading do
      reading_progress { Faker::Number.decimal(l_digits: 2, r_digits: 1) }
      last_read_at { Faker::Time.between(from: 7.days.ago, to: Time.current) }
    end

    # 已读完
    trait :finished do
      reading_progress { 100.0 }
      last_read_at { Faker::Time.between(from: 30.days.ago, to: Time.current) }
    end
  end
end
