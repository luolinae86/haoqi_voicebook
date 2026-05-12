# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Grades", type: :request do
  # ==================== 获取年级列表 ====================
  describe "GET /api/grades" do
    it "返回所有年级列表" do
      create_list(:grade, 3)

      get "/api/grades"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:grades]).to be_an(Array)
      expect(json_response[:response][:data][:grades].size).to eq(3)
    end

    it "每个年级包含必要字段" do
      grade = create(:grade, name: "四年级", group_name: "小学", description: "小学四年级")

      get "/api/grades"

      item = json_response[:response][:data][:grades].first
      expect(item[:id]).to eq(grade.id)
      expect(item[:name]).to eq("四年级")
      expect(item[:group_name]).to eq("小学")
      expect(item[:description]).to eq("小学四年级")
    end

    it "按 id 排序" do
      grade1 = create(:grade, name: "一年级")
      grade2 = create(:grade, name: "二年级")
      grade3 = create(:grade, name: "三年级")

      get "/api/grades"

      ids = json_response[:response][:data][:grades].map { |g| g[:id] }
      expect(ids).to eq([grade1.id, grade2.id, grade3.id])
    end

    it "没有年级时返回空数组" do
      get "/api/grades"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:grades]).to eq([])
    end

    it "不需要登录即可访问" do
      get "/api/grades"

      expect([200, 201]).to include(response.status)
    end
  end
end
