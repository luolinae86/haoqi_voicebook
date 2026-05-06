# frozen_string_literal: true

require "rails_helper"

RSpec.describe Grade, type: :model do
  # 关联测试
  describe "associations" do
    it { should have_many(:app_users).class_name("AppUser").dependent(:nullify) }
    it { should have_many(:books).dependent(:nullify) }
    it { should have_many(:collections).dependent(:nullify) }
    it { should have_many(:recommendations).dependent(:nullify) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:grade) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should validate_presence_of(:level) }
    it { should validate_uniqueness_of(:level) }
    it { should validate_presence_of(:sort_order) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 sort_order 升序排列" do
        grade3 = create(:grade, sort_order: 3)
        grade1 = create(:grade, sort_order: 1)
        grade2 = create(:grade, sort_order: 2)

        expect(Grade.ordered).to eq([grade1, grade2, grade3])
      end
    end
  end
end
