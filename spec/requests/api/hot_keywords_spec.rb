# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Hot Keywords", type: :request do
  let(:user) { create(:app_user) }
  let(:auth_params) { { uuid: user.uuid } }

  # ==================== 搜索记录 ====================
  describe "GET /api/books/search" do
    it "每次搜索都创建 UserSearch 记录" do
      expect {
        get "/api/books/search", params: auth_params.merge(keyword: "西游记")
      }.to change(UserSearch, :count).by(1)

      record = UserSearch.last
      expect(record.app_user_id).to eq(user.id)
      expect(record.keyword).to eq("西游记")
    end

    it "同一关键词多次搜索会创建多条记录" do
      get "/api/books/search", params: auth_params.merge(keyword: "西游记")
      get "/api/books/search", params: auth_params.merge(keyword: "西游记")

      expect(UserSearch.where(keyword: "西游记").count).to eq(2)
    end

    it "不同关键词分别创建记录" do
      get "/api/books/search", params: auth_params.merge(keyword: "西游记")
      get "/api/books/search", params: auth_params.merge(keyword: "海底小纵队")

      expect(UserSearch.count).to eq(2)
    end
  end

  # ==================== 热门搜索关键词 ====================
  describe "GET /api/books/hot_keywords" do
    it "无搜索记录时返回空数组" do
      get "/api/books/hot_keywords", params: auth_params

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:keywords]).to eq([])
    end

    it "返回按搜索次数排序的关键词" do
      UserSearch.create!(app_user: user, keyword: "西游记")
      UserSearch.create!(app_user: user, keyword: "西游记")
      UserSearch.create!(app_user: user, keyword: "西游记")
      UserSearch.create!(app_user: user, keyword: "海底小纵队")
      UserSearch.create!(app_user: user, keyword: "海底小纵队")

      get "/api/books/hot_keywords", params: auth_params

      expect(response).to have_http_status(200)
      keywords = json_response[:response][:data][:keywords]
      expect(keywords.first[:keyword]).to eq("西游记")
      expect(keywords.second[:keyword]).to eq("海底小纵队")
    end

    it "limit 参数限制返回数量" do
      5.times { |i| UserSearch.create!(app_user: user, keyword: "关键词#{i}") }

      get "/api/books/hot_keywords", params: auth_params.merge(limit: 3)

      keywords = json_response[:response][:data][:keywords]
      expect(keywords.size).to eq(3)
    end

    it "多用户的搜索会合并统计" do
      other_user = create(:app_user)
      UserSearch.create!(app_user: user, keyword: "西游记")
      UserSearch.create!(app_user: other_user, keyword: "西游记")
      UserSearch.create!(app_user: other_user, keyword: "海底小纵队")

      get "/api/books/hot_keywords", params: auth_params

      keywords = json_response[:response][:data][:keywords]
      # 西游记被搜了2次，海底小纵队1次
      expect(keywords.first[:keyword]).to eq("西游记")
      expect(keywords.second[:keyword]).to eq("海底小纵队")
    end

    it "未登录返回未授权" do
      get "/api/books/hot_keywords", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end
end
