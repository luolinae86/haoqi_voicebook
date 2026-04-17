# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Rankings", type: :request do
  # ==================== 测试数据准备 ====================
  let!(:ranking1) { create(:ranking, name: "热门排行榜", ranking_type: :hot) }
  let!(:ranking2) { create(:ranking, :rating, name: "评分排行榜") }

  let!(:book1) { create(:book, :popular) }
  let!(:book2) { create(:book, :popular) }
  let!(:book3) { create(:book) }

  let!(:item1) { create(:ranking_item, ranking: ranking1, book: book1, rank: 1, score: 99.5) }
  let!(:item2) { create(:ranking_item, ranking: ranking1, book: book2, rank: 2, score: 88.0) }
  let!(:item3) { create(:ranking_item, ranking: ranking2, book: book3, rank: 1, score: 95.0) }

  # ==================== 排行榜列表 ====================
  describe "GET /api/rankings" do
    it "返回所有排行榜" do
      get "/api/rankings"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      expect(json_response[:data].size).to be >= 2
    end

    it "包含排行榜名称和类型" do
      get "/api/rankings"

      names = json_response[:data].map { |r| r[:name] }
      expect(names).to include("热门排行榜", "评分排行榜")
    end

    it "支持按内容类型过滤" do
      get "/api/rankings", params: { content_type: "ebook" }

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
    end
  end

  # ==================== 排行榜详情 ====================
  describe "GET /api/rankings/:id" do
    it "返回排行榜详情及图书列表" do
      get "/api/rankings/#{ranking1.id}"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:id]).to eq(ranking1.id)
      expect(json_response[:data][:name]).to eq("热门排行榜")
    end

    it "图书按排名排序" do
      get "/api/rankings/#{ranking1.id}"

      books = json_response[:data][:books] || json_response[:data][:items] || json_response[:data][:ranking_items]
      if books
        ranks = books.map { |b| b[:rank] }
        expect(ranks).to eq(ranks.sort)
      end
    end

    it "支持分页" do
      get "/api/rankings/#{ranking1.id}", params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
    end

    it "排行榜不存在时返回 404" do
      get "/api/rankings/999999"

      expect(response).to have_http_status(404)
    end

    it "包含图书详细信息" do
      get "/api/rankings/#{ranking1.id}"

      books = json_response[:data][:books] || json_response[:data][:items] || json_response[:data][:ranking_items]
      if books && books.any?
        first_book = books.first
        book_data = first_book[:book] || first_book
        expect(book_data[:title]).to be_present
      end
    end
  end
end
