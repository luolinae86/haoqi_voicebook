# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category, type: :model do
  describe "associations" do
    it { is_expected.to have_and_belong_to_many(:compilations) }
    it { is_expected.to have_many(:books) }
    it { is_expected.to have_many(:category_subs).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "scopes" do
    describe ".by_level" do
      it "按 level 筛选" do
        create(:category, level: 1, name: "一级")
        l2 = create(:category, level: 2, name: "二级")

        expect(Category.by_level(2)).to include(l2)
        expect(Category.by_level(2)).not_to include(Category.by_level(1).first)
      end
    end

    describe ".sorted" do
      it "按 sn 升序排列" do
        create(:category, sn: 10, name: "后")
        first = create(:category, sn: 1, name: "前")

        expect(Category.sorted.first).to eq(first)
      end
    end
  end
end
