# frozen_string_literal: true

# == Schema Information
#
# Table name: leaderboards
#
#  name               :string           not null, comment: '榜单名称'
#  slug               :string           not null, comment: '唯一标识'
#  ranking_type       :integer          not null, default(0), comment: '0-自动 1-手动'
#  auto_rule          :string           comment: '自动规则'
#  category_filter    :string           comment: '按分类过滤'
#  limit_count        :integer          default(50), comment: '最多展示数量'
#  is_active          :boolean          not null, default(true), comment: '是否启用'
#  sort_order         :integer          not null, default(0), comment: '展示排序'
#  last_calculated_at :datetime         comment: '自动榜单最后计算时间'
#  description        :text             comment: '榜单描述'
#
require 'rails_helper'

RSpec.describe Leaderboard, type: :model do
  describe 'associations' do
    it 'has many leaderboard_items' do
      expect(Leaderboard.reflect_on_association(:leaderboard_items)).to be_present
    end

    it 'has many books through leaderboard_items' do
      expect(Leaderboard.reflect_on_association(:books)).to be_present
    end
  end

  describe 'enums' do
    it 'defines ranking_type enum' do
      expect(Leaderboard.ranking_types).to eq({ 'auto' => 0, 'manual' => 1 })
    end
  end

  describe 'scopes' do
    it 'returns only active leaderboards' do
      create(:leaderboard, name: 'Active', is_active: true, sort_order: 1)
      create(:leaderboard, name: 'Inactive', is_active: false, sort_order: 2)

      expect(Leaderboard.active.map(&:name)).to eq(['Active'])
    end

    it 'orders by sort_order' do
      create(:leaderboard, name: 'Second', is_active: true, sort_order: 2)
      create(:leaderboard, name: 'First', is_active: true, sort_order: 1)

      expect(Leaderboard.active.map(&:name)).to eq(['First', 'Second'])
    end
  end

  describe '#calculate!' do
    let!(:leaderboard) do
      create(:leaderboard, name: '热读榜', slug: 'hot_reading', ranking_type: :auto, auto_rule: 'weekly_readers')
    end
    let!(:book1) { create(:book, status: :published) }
    let!(:book2) { create(:book, status: :published) }
    let!(:book3) { create(:book, status: :published) }

    before do
      BookStats.create!(book_id: book1.id, weekly_readers: 100)
      BookStats.create!(book_id: book2.id, weekly_readers: 300)
      BookStats.create!(book_id: book3.id, weekly_readers: 200)
    end

    it 'populates items in correct order' do
      leaderboard.calculate!

      items = leaderboard.leaderboard_items.ordered
      expect(items.size).to eq(3)
      expect(items[0].book_id).to eq(book2.id)
      expect(items[0].rank).to eq(1)
      expect(items[1].book_id).to eq(book3.id)
      expect(items[2].book_id).to eq(book1.id)
    end

    it 'updates last_calculated_at' do
      expect { leaderboard.calculate! }.to change { leaderboard.reload.last_calculated_at }
    end

    it 'does nothing for manual leaderboards' do
      manual = create(:leaderboard, name: 'Manual', slug: 'manual_list', ranking_type: :manual)
      manual.calculate!
      expect(manual.leaderboard_items.count).to eq(0)
    end
  end
end
