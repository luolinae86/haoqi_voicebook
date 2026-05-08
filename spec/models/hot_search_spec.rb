# frozen_string_literal: true

require "rails_helper"

RSpec.describe HotSearch, type: :model do
  # 验证测试
  describe "validations" do
    subject { create(:hot_search) }

    it { is_expected.to validate_presence_of(:keyword) }
    it { is_expected.to validate_uniqueness_of(:keyword).case_insensitive }
    it { is_expected.to validate_presence_of(:sort_order) }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按 sort_order 升序排列" do
        hs3 = create(:hot_search, sort_order: 3)
        hs1 = create(:hot_search, sort_order: 1)
        hs2 = create(:hot_search, sort_order: 2)

        expect(HotSearch.ordered).to eq([hs1, hs2, hs3])
      end
    end

    describe ".popular" do
      it "按搜索次数降序排列" do
        create(:hot_search, search_count: 10)
        hs_high = create(:hot_search, search_count: 100)

        expect(HotSearch.popular.first).to eq(hs_high)
      end
    end
  end

  # 实例方法测试
  describe "#increment_count!" do
    it "增加搜索次数" do
      hot_search = create(:hot_search, search_count: 5)
      hot_search.increment_count!
      expect(hot_search.reload.search_count).to eq(6)
    end
  end
end
