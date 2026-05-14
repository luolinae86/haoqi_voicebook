# frozen_string_literal: true

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
require "rails_helper"

RSpec.describe BlacklistedBook, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:parental_control) }
    it { is_expected.to belong_to(:book) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:blacklisted_book) }

    it { is_expected.to validate_uniqueness_of(:parental_control_id).scoped_to(:book_id).with_message("该图书已在黑名单中") }
  end
end
