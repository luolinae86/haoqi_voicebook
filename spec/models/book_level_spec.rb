# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookLevel, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(50) }
    it { is_expected.to validate_presence_of(:sn) }
    it { is_expected.to validate_numericality_of(:sn).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    describe ".sorted" do
      it "按 sn 升序排列" do
        create(:book_level, sn: 10, name: "High")
        low = create(:book_level, sn: 1, name: "Low")

        expect(BookLevel.sorted.first).to eq(low)
      end
    end
  end
end
