# frozen_string_literal: true

# 图书黑名单工厂
# == Schema Information
#
# Table name: blacklisted_books
#
#  id                              :bigint           not null, primary key
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  book_id(图书ID)                 :integer          not null
#  parental_control_id(家长管控ID) :integer          not null
#
# Indexes
#
#  index_blacklisted_books_on_book_id                          (book_id)
#  index_blacklisted_books_on_parental_control_id              (parental_control_id)
#  index_blacklisted_books_on_parental_control_id_and_book_id  (parental_control_id,book_id) UNIQUE
#
FactoryBot.define do
  factory :blacklisted_book do
    association :parental_control
    association :book
  end
end
