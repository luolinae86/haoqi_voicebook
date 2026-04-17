# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Health Check", type: :request do
  describe "GET /api" do
    it "返回 Hello World 欢迎信息" do
      get "/api"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:message]).to include("Hello World")
      expect(json_response[:data][:version]).to be_present
    end
  end

  describe "GET /api/up" do
    it "返回健康检查状态" do
      get "/api/up"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:status]).to eq("ok")
      expect(json_response[:data][:time]).to be_present
    end
  end
end
