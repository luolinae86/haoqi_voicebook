# frozen_string_literal: true

# == Schema Information
#
# Table name: packages
#
#  id             :bigint           not null, primary key
#  discount_tag   :string(255)
#  effective_days :integer
#  is_delete      :boolean          default(FALSE)
#  is_discount    :boolean          default(FALSE)
#  name           :string(255)
#  origin_price   :float(24)
#  price          :float(24)
#  sn             :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_packages_on_is_delete  (is_delete)
#
require "rails_helper"

RSpec.describe Package, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "允许 name 最长 100 字符" do
      package = build(:package, name: "a" * 100)
      expect(package).to be_valid
    end

    it "限制 name 超过 100 字符无效" do
      package = build(:package, name: "a" * 101)
      expect(package).not_to be_valid
    end

    it "不允许 price 为 nil" do
      package = build(:package, price: nil)
      expect(package).not_to be_valid
    end

    it "允许 price 为 0" do
      package = build(:package, price: 0)
      expect(package).to be_valid
    end

    it "不允许 price 为负数" do
      package = build(:package, price: -1)
      expect(package).not_to be_valid
    end
  end

  describe "scopes" do
    describe ".active" do
      it "只返回未被删除的套餐" do
        active = create(:package, name: "月度", is_delete: false)
        deleted = create(:package, name: "已下架", is_delete: true)

        expect(Package.active).to include(active)
        expect(Package.active).not_to include(deleted)
      end
    end

    describe ".sorted" do
      it "按 sn 升序排列" do
        create(:package, name: "年度", sn: 3)
        create(:package, name: "月度", sn: 1)
        create(:package, name: "季度", sn: 2)

        sorted_names = Package.sorted.pluck(:name)
        expect(sorted_names).to eq(["月度", "季度", "年度"])
      end
    end
  end

  describe "default_scope" do
    it "默认不返回已删除的套餐" do
      create(:package, name: "月度", is_delete: false)
      create(:package, name: "已下架", is_delete: true)

      expect(Package.all.map(&:name)).not_to include("已下架")
    end

    it "默认按 sn 升序排列" do
      create(:package, name: "年度", sn: 3)
      create(:package, name: "月度", sn: 1)
      create(:package, name: "季度", sn: 2)

      expect(Package.all.map(&:name)).to eq(["月度", "季度", "年度"])
    end
  end
end
