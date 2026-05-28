# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Books Categories", type: :request do
  let(:user) { create(:app_user) }

  # ==================== GET /api/categories/list ====================
  describe "GET /api/categories/list" do
    it "返回按 sn 排序的所有分类" do
      create(:category, name: "文学", sn: 2)
      create(:category, name: "科普", sn: 1)
      create(:category, name: "历史", sn: 3)

      get "/api/categories/list", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:categories].size).to eq(3)
      expect(data[:categories].map { |c| c[:name] }).to eq(["科普", "文学", "历史"])
    end

    it "level 参数过滤指定层级" do
      create(:category, name: "一级1", level: 1, sn: 1)
      create(:category, name: "二级1", level: 2, sn: 1)
      create(:category, name: "一级2", level: 1, sn: 2)

      get "/api/categories/list", params: { uuid: user.uuid, level: 1 }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:categories].all? { |c| c[:level] == 1 }).to be true
      expect(data[:categories].size).to eq(2)
    end

    it "返回分类的所有字段" do
      category = create(:category, name: "测试", level: 1, sn: 5, active: true)

      get "/api/categories/list", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      c = data[:categories].find { |x| x[:id] == category.id }
      expect(c[:name]).to eq("测试")
      expect(c[:level]).to eq(1)
      expect(c[:sn]).to eq(5)
      expect(c[:active]).to be true
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/categories/list"

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 返回未授权" do
      get "/api/categories/list", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it "无分类时返回空数组" do
      get "/api/categories/list", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:categories]).to eq([])
    end
  end
end
