# frozen_string_literal: true

require "rails_helper"

RSpec.describe Supplier, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }

    it "uniqueness of name" do
      create(:supplier, name: "Unique Supplier")
      duplicate = build(:supplier, name: "Unique Supplier")
      expect(duplicate).not_to be_valid
    end
  end
end
