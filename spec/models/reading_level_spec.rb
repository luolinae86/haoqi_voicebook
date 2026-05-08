# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReadingLevel, type: :model do
  # 验证测试
  describe "validations" do
    subject { create(:reading_level) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_presence_of(:level) }
    it { is_expected.to validate_uniqueness_of(:level) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 level 升序排列" do
        level3 = create(:reading_level, level: 3)
        level1 = create(:reading_level, level: 1)
        level2 = create(:reading_level, level: 2)

        expect(ReadingLevel.ordered).to eq([level1, level2, level3])
      end
    end
  end
end
