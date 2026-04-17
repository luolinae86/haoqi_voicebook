# frozen_string_literal: true

require "rails_helper"

RSpec.describe Recommendation, type: :model do
  # 关联测试
  describe "associations" do
    it { should belong_to(:target_grade).class_name("Grade").optional }
    it { should have_many(:recommendation_items).dependent(:destroy) }
    it { should have_many(:books).through(:recommendation_items) }
  end

  # 验证测试
  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:sort_order) }
  end

  # 枚举测试
  describe "enums" do
    it { should define_enum_for(:recommendation_type).with_values(featured: 0, graded: 1, trending: 2, new_book: 3, topic: 4) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 sort_order 升序排列" do
        rec3 = create(:recommendation, sort_order: 3)
        rec1 = create(:recommendation, sort_order: 1)
        rec2 = create(:recommendation, sort_order: 2)

        expect(Recommendation.ordered).to eq([rec1, rec2, rec3])
      end
    end
  end
end
