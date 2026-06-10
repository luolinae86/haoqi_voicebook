# frozen_string_literal: true

# == Schema information
#
# Table name: catalogues
#
#  id                                :bigint           not null, primary key
#  book_id                           :bigint           not null, comment: '图书ID'
#  chapter_number                    :integer          not null, comment: '章节序号'
#  chapter_name                      :string           not null, comment: '章节名称'
#  start_page_number                 :integer          not null, comment: '起始页码'
#  is_free(是否免费)                  :boolean          default(FALSE), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#
# Indexes
#
#  index_catalogues_on_book_id  (book_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
# == Schema Information
#
# Table name: catalogues
#
#  id                          :bigint           not null, primary key
#  chapter_name(章节名称)      :string(255)      not null
#  chapter_number(章节序号)    :integer          not null
#  is_free(是否免费)           :boolean          default(FALSE), not null
#  start_page_number(起始页码) :integer          not null
#  word_count(章节字数)        :integer          default(0), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  book_id(图书ID)             :bigint           not null
#
# Indexes
#
#  index_catalogues_on_book_id  (book_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#
FactoryBot.define do
  factory :catalogue do
    association :book
    sequence(:chapter_number) { |n| n }
    sequence(:chapter_name) { |n| "第#{n}章" }
    sequence(:start_page_number) { |n| n * 10 }
    is_free { false }
  end
end
