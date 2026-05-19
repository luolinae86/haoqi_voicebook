# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Leaderboards', type: :request do
  let(:user) { create(:app_user) }

  # ==================== 获取所有启用的排行榜 ====================
  describe 'GET /api/leaderboards' do
    it '返回启用的排行榜列表' do
      create(:leaderboard, name: '热读榜', slug: 'hot_reading', is_active: true, sort_order: 1)
      create(:leaderboard, name: '高分榜', slug: 'high_rating', is_active: true, sort_order: 2)
      create(:leaderboard, name: '隐藏榜', slug: 'hidden', is_active: false, sort_order: 3)

      get '/api/leaderboards', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      leaderboards = json_response[:response][:data][:leaderboards]
      expect(leaderboards.size).to eq(2)
      expect(leaderboards.map { |l| l[:slug] }).to eq(['hot_reading', 'high_rating'])
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/leaderboards'

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 获取指定排行榜的书籍列表 ====================
  describe 'GET /api/leaderboards/:slug' do
    let!(:leaderboard) do
      create(:leaderboard, name: '热读榜', slug: 'hot_reading', ranking_type: :auto, auto_rule: 'weekly_readers')
    end
    let!(:book1) { create(:book, name: '热门书', status: :published) }
    let!(:book2) { create(:book, name: '冷门书', status: :published) }

    before do
      BookStats.create!(book_id: book1.id, weekly_readers: 100)
      BookStats.create!(book_id: book2.id, weekly_readers: 50)
    end

    it '返回排行榜书籍列表' do
      get "/api/leaderboards/#{leaderboard.slug}", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:leaderboard][:name]).to eq('热读榜')
      expect(data[:books].size).to eq(2)
      expect(data[:books].first[:book_name]).to eq('热门书')
    end

    it '排行榜不存在时返回错误' do
      get '/api/leaderboards/nonexistent', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it '未提供 uuid 时返回参数错误' do
      get "/api/leaderboards/#{leaderboard.slug}"

      expect(response).to have_http_status(200)
    end
  end
end
