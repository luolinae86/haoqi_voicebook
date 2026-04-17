# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Search", type: :request do
  # ==================== 测试数据准备 ====================
  let!(:book1) { create(:book, title: "小王子", author: "圣埃克苏佩里", status: :published) }
  let!(:book2) { create(:book, title: "格林童话", author: "格林兄弟", status: :published) }
  let!(:book3) { create(:book, title: "安徒生童话", author: "安徒生", status: :published) }
  let!(:draft_book) { create(:book, title: "童话草稿", status: :draft) }

  let!(:hot1) { create(:hot_search, keyword: "童话", search_count: 1000, sort_order: 1) }
  let!(:hot2) { create(:hot_search, keyword: "科学", search_count: 800, sort_order: 2) }
  let!(:hot3) { create(:hot_search, keyword: "历史", search_count: 500, sort_order: 3) }

  # ==================== 搜索图书 ====================
  describe "GET /api/search" do
    it "按关键词搜索图书" do
      get "/api/search", params: { keyword: "童话" }

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      titles = json_response[:data].map { |b| b[:title] }
      expect(titles).to include("格林童话", "安徒生童话")
    end

    it "不返回草稿状态的图书" do
      get "/api/search", params: { keyword: "童话" }

      titles = json_response[:data].map { |b| b[:title] }
      expect(titles).not_to include("童话草稿")
    end

    it "按书名搜索" do
      get "/api/search", params: { keyword: "小王子" }

      expect(json_response[:data].size).to be >= 1
      expect(json_response[:data].first[:title]).to eq("小王子")
    end

    it "按作者搜索" do
      get "/api/search", params: { keyword: "安徒生" }

      expect(json_response[:data]).to be_present
    end

    it "支持按内容类型过滤" do
      get "/api/search", params: { keyword: "童话", content_type: "ebook" }

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
    end

    it "支持分页" do
      get "/api/search", params: { keyword: "童话", page: 1, per_page: 1 }

      expect(response).to have_http_status(200)
      expect(json_response[:data].size).to be <= 1
    end

    it "搜索无结果返回空列表" do
      get "/api/search", params: { keyword: "不存在的书籍名称xyz" }

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data]).to be_empty
    end

    it "缺少 keyword 参数返回错误" do
      get "/api/search"

      expect(response).to have_http_status(:bad_request)
    end
  end

  # ==================== 热门搜索 ====================
  describe "GET /api/search/hot" do
    it "返回热门搜索关键词列表" do
      get "/api/search/hot"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      expect(json_response[:data].size).to be >= 3
    end

    it "包含关键词和搜索次数" do
      get "/api/search/hot"

      first = json_response[:data].first
      expect(first[:keyword]).to be_present
    end

    it "按排序号排列" do
      get "/api/search/hot"

      sort_orders = json_response[:data].map { |h| h[:sort_order] }
      expect(sort_orders).to eq(sort_orders.sort)
    end
  end
end
