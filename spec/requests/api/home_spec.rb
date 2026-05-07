# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Home", type: :request do
  # ==================== 测试数据准备 ====================
  let(:grade) { create(:grade) }

  let!(:banner1) { create(:banner, sort_order: 1) }
  let!(:banner2) { create(:banner, sort_order: 2) }
  let!(:inactive_banner) { create(:banner, :inactive) }

  let!(:recommendation) { create(:recommendation, sort_order: 1) }
  let!(:book1) { create(:book) }
  let!(:book2) { create(:book) }
  let!(:rec_item1) { create(:recommendation_item, recommendation: recommendation, book: book1, sort_order: 1) }
  let!(:rec_item2) { create(:recommendation_item, recommendation: recommendation, book: book2, sort_order: 2) }

  let!(:reading_level1) { create(:reading_level, level: 1) }
  let!(:reading_level2) { create(:reading_level, level: 2) }

  let!(:collection) { create(:collection, sort_order: 1) }
  let!(:col_item1) { create(:collection_item, collection: collection, book: book1, sort_order: 1) }
  let!(:col_item2) { create(:collection_item, collection: collection, book: book2, sort_order: 2) }

  # ==================== 首页数据 ====================
  describe "GET /api/home" do
    it "返回首页聚合数据" do
      get "/api/home"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:banners]).to be_present
    end

    it "支持按年级过滤" do
      get "/api/home", params: { grade_id: grade.id }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end
  end

  # ==================== 轮播图 ====================
  describe "GET /api/home/banners" do
    it "返回活跃的轮播图" do
      get "/api/home/banners"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:banners]).to be_an(Array)
    end

    it "轮播图按排序号排列" do
      get "/api/home/banners"

      sort_orders = json_response[:banners].map { |b| b[:sort_order] }
      expect(sort_orders).to eq(sort_orders.sort)
    end

    it "不返回已停用的轮播图" do
      get "/api/home/banners"

      titles = json_response[:banners].map { |b| b[:title] }
      expect(titles).not_to include(inactive_banner.title)
    end
  end

  # ==================== 推荐列表 ====================
  describe "GET /api/home/recommendations" do
    it "返回推荐列表及关联图书" do
      get "/api/home/recommendations"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:recommendations]).to be_an(Array)
    end

    it "支持按年级过滤" do
      get "/api/home/recommendations", params: { grade_id: grade.id }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "支持按类型过滤" do
      get "/api/home/recommendations", params: { type: "daily" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end
  end

  # ==================== 阅读等级 ====================
  describe "GET /api/home/reading_levels" do
    it "返回阅读等级列表" do
      get "/api/home/reading_levels"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:levels]).to be_an(Array)
      expect(json_response[:levels].size).to be >= 2
    end

    it "按等级排序" do
      get "/api/home/reading_levels"

      levels = json_response[:levels].map { |l| l[:level] }
      expect(levels).to eq(levels.sort)
    end
  end

  # ==================== 书单列表 ====================
  describe "GET /api/home/collections" do
    it "返回书单列表" do
      get "/api/home/collections"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
    end

    it "支持分页" do
      get "/api/home/collections", params: { page: 1, per_page: 5 }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "支持按年级过滤" do
      get "/api/home/collections", params: { grade_id: grade.id }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "支持按类型过滤" do
      get "/api/home/collections", params: { type: "featured" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end
  end

  # ==================== 书单详情 ====================
  describe "GET /api/home/collections/:id" do
    it "返回书单详情及图书列表" do
      get "/api/home/collections/#{collection.id}"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:collection][:id]).to eq(collection.id)
      expect(json_response[:collection][:title]).to eq(collection.title)
    end

    it "支持分页获取书单图书" do
      get "/api/home/collections/#{collection.id}", params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "书单不存在时返回 404" do
      get "/api/home/collections/999999"

      expect(response).to have_http_status(404)
    end
  end
end
