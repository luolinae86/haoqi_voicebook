# frozen_string_literal: true

require "rails_helper"

RSpec.describe BlacklistedBook, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:parental_control) }
    it { should belong_to(:book) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:blacklisted_book) }

    it { should validate_uniqueness_of(:parental_control_id).scoped_to(:book_id).with_message("该图书已在黑名单中") }
  end
end
