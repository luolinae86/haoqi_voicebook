# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:parent).class_name("Category").optional }
    it { is_expected.to have_many(:children).class_name("Category").with_foreign_key(:parent_id).dependent(:destroy) }
    it { is_expected.to have_many(:books).dependent(:nullify) }
  end

  # 验证测试
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:sort_order) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".roots" do
      it "只返回顶级分类（parent_id 为空）" do
        root = create(:category, parent: nil)
        child = create(:category, parent: root)

        expect(Category.roots).to include(root)
        expect(Category.roots).not_to include(child)
      end
    end

    describe ".ordered" do
      it "按 sort_order 升序排列" do
        cat3 = create(:category, sort_order: 3)
        cat1 = create(:category, sort_order: 1)
        cat2 = create(:category, sort_order: 2)

        expect(Category.ordered).to eq([cat1, cat2, cat3])
      end
    end
  end
end
