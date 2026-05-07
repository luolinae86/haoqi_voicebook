# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Categories", type: :request do
  # ==================== 测试数据准备 ====================
  let!(:root_category1) { create(:category, name: "文学", sort_order: 1) }
  let!(:root_category2) { create(:category, name: "科学", sort_order: 2) }
  let!(:child_category1) { create(:category, name: "童话", parent_id: root_category1.id, sort_order: 1) }
  let!(:child_category2) { create(:category, name: "诗歌", parent_id: root_category1.id, sort_order: 2) }

  let!(:book_in_category) { create(:book, category: child_category1) }
  let!(:another_book) { create(:book, category: child_category1) }

  let!(:grade1) { create(:grade, name: "一年级", level: 1, sort_order: 1) }
  let!(:grade2) { create(:grade, name: "二年级", level: 2, sort_order: 2) }

  # ==================== 分类列表 ====================
  describe "GET /api/categories" do
    it "返回根分类列表" do
      get "/api/categories"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:categories]).to be_an(Array)
      names = json_response[:categories].map { |c| c[:name] }
      expect(names).to include("文学", "科学")
    end

    it "分类按排序号排列" do
      get "/api/categories"

      sort_orders = json_response[:categories].map { |c| c[:sort_order] }
      expect(sort_orders).to eq(sort_orders.sort)
    end

    it "通过 parent_id 获取子分类" do
      get "/api/categories", params: { parent_id: root_category1.id }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      names = json_response[:categories].map { |c| c[:name] }
      expect(names).to include("童话", "诗歌")
    end
  end

  # ==================== 分类详情 ====================
  describe "GET /api/categories/:id" do
    it "返回分类详情及子分类" do
      get "/api/categories/#{root_category1.id}"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:category][:id]).to eq(root_category1.id)
      expect(json_response[:category][:name]).to eq("文学")
    end

    it "分类不存在时返回 404" do
      get "/api/categories/999999"

      expect(response).to have_http_status(404)
    end
  end

  # ==================== 分类下的图书 ====================
  describe "GET /api/categories/:id/books" do
    it "返回分类下的图书列表" do
      get "/api/categories/#{child_category1.id}/books"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      expect(json_response[:data].size).to eq(2)
    end

    it "支持按内容类型过滤" do
      get "/api/categories/#{child_category1.id}/books", params: { content_type: "ebook" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "支持分页" do
      get "/api/categories/#{child_category1.id}/books", params: { page: 1, per_page: 1 }

      expect(response).to have_http_status(200)
      expect(json_response[:data].size).to be <= 1
    end
  end

  # ==================== 年级列表 ====================
  describe "GET /api/grades" do
    it "返回年级列表" do
      get "/api/grades"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:grades]).to be_an(Array)
      expect(json_response[:grades].size).to be >= 2
    end

    it "年级按排序号排列" do
      get "/api/grades"

      sort_orders = json_response[:grades].map { |g| g[:sort_order] }
      expect(sort_orders).to eq(sort_orders.sort)
    end

    it "包含年级名称和级别信息" do
      get "/api/grades"

      first_grade = json_response[:grades].find { |g| g[:name] == "一年级" }
      expect(first_grade).to be_present
      expect(first_grade[:level]).to eq(1)
    end
  end
end
