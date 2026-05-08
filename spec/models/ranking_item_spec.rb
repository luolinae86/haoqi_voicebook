# frozen_string_literal: true

require "rails_helper"

RSpec.describe RankingItem, type: :model do
  # 关联测试
  describe "associations" do
    it { is_expected.to belong_to(:ranking) }
    it { is_expected.to belong_to(:book) }
  end

  # 验证测试
  describe "validations" do
    subject { create(:ranking_item) }

    it { is_expected.to validate_presence_of(:rank) }
    it { is_expected.to validate_numericality_of(:rank).is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:ranking_id).scoped_to(:book_id).with_message("该图书已在排行榜中") }
  end

  # 作用域测试
  describe "scopes" do
    describe ".ordered" do
      it "按排名升序排列" do
        ranking = create(:ranking)
        item3 = create(:ranking_item, ranking: ranking, rank: 3)
        item1 = create(:ranking_item, ranking: ranking, rank: 1)
        item2 = create(:ranking_item, ranking: ranking, rank: 2)

        expect(ranking.ranking_items.ordered).to eq([item1, item2, item3])
      end
    end
  end
end
