# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Books", type: :request do
  let(:user) { create(:app_user) }
  let(:headers) { auth_headers(user) }

  let!(:book) { create(:book) }

  # ==================== 图书列表 ====================
  describe "GET /api/books" do
    it "返回图书列表" do
      get "/api/books"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
    end

    it "支持分页" do
      get "/api/books", params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(200)
      expect(json_response[:data].size).to be <= 2
    end
  end

  # ==================== 图书详情 ====================
  describe "GET /api/books/:id" do
    it "返回图书详情" do
      get "/api/books/#{book.id}"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:book][:id]).to eq(book.id)
      expect(json_response[:book][:name]).to eq(book.name)
    end

    it "图书不存在时返回 404" do
      get "/api/books/999999"

      expect(response).to have_http_status(404)
    end
  end
end
