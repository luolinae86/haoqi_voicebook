# frozen_string_literal: true

# 书签工厂
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
FactoryBot.define do
  factory :bookmark do
    association :app_user
    association :book
    position { Faker::Number.decimal(l_digits: 2, r_digits: 1) }
  end
end
