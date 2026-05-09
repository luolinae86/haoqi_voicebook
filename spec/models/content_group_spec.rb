# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentGroup, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:recommend) }
    it { is_expected.to have_many(:contents).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:group_type) }
  end

  describe "enums" do
    it "定义了 group_type 枚举" do
      expect(ContentGroup.group_types).to include("multi_images", "one_row_three_columns", "one_row_display")
    end
  end
end
