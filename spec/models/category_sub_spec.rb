# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategorySub, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:category) }
    it { is_expected.to have_and_belong_to_many(:books) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:category_id) }
  end

  describe "scopes" do
    describe ".sorted" do
      it "按 sn 升序排列" do
        category = create(:category)
        create(:category_sub, category: category, sn: 10, name: "后")
        first = create(:category_sub, category: category, sn: 1, name: "前")

        expect(CategorySub.sorted.first).to eq(first)
      end
    end
  end
end
