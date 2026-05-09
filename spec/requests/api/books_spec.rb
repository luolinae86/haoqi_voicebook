# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Books", type: :request do
  let(:user) { create(:app_user) }
  let(:vip_user) { create(:app_user, :vip) }
  let(:headers) { auth_headers(user) }
  let(:vip_headers) { auth_headers(vip_user) }

  let!(:ebook) { create(:book, content_type: :ebook) }
  let!(:audio_book) { create(:book, :audio) }
  let!(:picture_book) { create(:book, :picture_book) }
  let!(:draft_book) { create(:book, :draft) }

  # ==================== 图书列表 ====================
  describe "GET /api/books" do
    it "返回已发布的图书列表" do
      get "/api/books"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      titles = json_response[:data].map { |b| b[:title] }
      expect(titles).not_to include(draft_book.title)
    end

    it "支持分页" do
      get "/api/books", params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(200)
      expect(json_response[:data].size).to be <= 2
    end

    context "按内容类型过滤" do
      it "过滤电子书" do
        get "/api/books", params: { content_type: "ebook" }

        expect(response).to have_http_status(200)
        expect(json_response[:data]).to all(include(content_type: "ebook"))
      end

      it "过滤有声书" do
        get "/api/books", params: { content_type: "audio" }

        expect(response).to have_http_status(200)
        expect(json_response[:data]).to all(include(content_type: "audio"))
      end
    end

    context "排序" do
      it "按热门排序" do
        get "/api/books", params: { sort_by: "popular" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
      end

      it "按评分排序" do
        get "/api/books", params: { sort_by: "rating" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
      end

      it "按最新排序" do
        get "/api/books", params: { sort_by: "recent" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
      end
    end
  end

  # ==================== 图书详情 ====================
  describe "GET /api/books/:id" do
    it "返回图书详情" do
      get "/api/books/#{ebook.id}"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:book][:id]).to eq(ebook.id)
      expect(json_response[:book][:title]).to eq(ebook.title)
      expect(json_response[:book][:author]).to be_present
      expect(json_response[:book][:content_type]).to eq("ebook")
    end

    it "图书不存在时返回 404" do
      get "/api/books/999999"

      expect(response).to have_http_status(404)
    end
  end
end
