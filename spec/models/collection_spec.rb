# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collection, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:target_grade).class_name("Grade").optional }
    it { is_expected.to have_many(:collection_items).dependent(:destroy) }
    it { is_expected.to have_many(:books).through(:collection_items) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:sort_order) }
  end

  # 枚举测试
  describe "enums" do
    it { is_expected.to define_enum_for(:collection_type).with_values(topic: 0, graded: 1, trending: 2, new_arrival: 3) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 sort_order 升序排列" do
        col3 = create(:collection, sort_order: 3)
        col1 = create(:collection, sort_order: 1)
        col2 = create(:collection, sort_order: 2)

        expect(Collection.ordered).to eq([col1, col2, col3])
      end
    end
  end
end
