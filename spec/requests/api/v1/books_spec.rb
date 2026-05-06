# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Books", type: :request do
  let(:user) { create(:app_user) }
  let(:vip_user) { create(:app_user, :vip) }
  let(:headers) { auth_headers(user) }
  let(:vip_headers) { auth_headers(vip_user) }

  let(:category) { create(:category) }
  let(:grade) { create(:grade) }

  let!(:ebook) { create(:book, content_type: :ebook, category: category, grade: grade) }
  let!(:audio_book) { create(:book, :audio, category: category, grade: grade) }
  let!(:picture_book) { create(:book, :picture_book) }
  let!(:draft_book) { create(:book, :draft) }

  # ==================== 图书列表 ====================
  describe "GET /api/books" do
    it "返回已发布的图书列表" do
      get "/api/books"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
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

    context "按分类过滤" do
      it "过滤指定分类的图书" do
        get "/api/books", params: { category_id: category.id }

        expect(response).to have_http_status(200)
        json_response[:data].each do |book|
          expect(book[:category_id]).to eq(category.id)
        end
      end
    end

    context "按年级过滤" do
      it "过滤指定年级的图书" do
        get "/api/books", params: { grade_id: grade.id }

        expect(response).to have_http_status(200)
        json_response[:data].each do |book|
          expect(book[:grade_id]).to eq(grade.id)
        end
      end
    end

    context "排序" do
      it "按热门排序" do
        get "/api/books", params: { sort_by: "popular" }

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end

      it "按评分排序" do
        get "/api/books", params: { sort_by: "rating" }

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end

      it "按最新排序" do
        get "/api/books", params: { sort_by: "recent" }

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end
    end
  end

  # ==================== 图书详情 ====================
  describe "GET /api/books/:id" do
    it "返回图书详情" do
      get "/api/books/#{ebook.id}"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:id]).to eq(ebook.id)
      expect(json_response[:data][:title]).to eq(ebook.title)
      expect(json_response[:data][:author]).to be_present
      expect(json_response[:data][:content_type]).to eq("ebook")
    end

    it "图书不存在时返回 404" do
      get "/api/books/999999"

      expect(response).to have_http_status(404)
    end
  end

  # ==================== 章节列表 ====================
  describe "GET /api/books/:id/chapters" do
    let!(:chapters) do
      3.times.map { |i| create(:chapter, book: ebook, sort_order: i + 1) }
    end

    it "返回章节列表" do
      get "/api/books/#{ebook.id}/chapters"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      expect(json_response[:data].size).to eq(3)
    end

    it "章节按排序号排列" do
      get "/api/books/#{ebook.id}/chapters"

      sort_orders = json_response[:data].map { |c| c[:sort_order] }
      expect(sort_orders).to eq(sort_orders.sort)
    end
  end

  # ==================== 章节内容 ====================
  describe "GET /api/books/:id/chapters/:chapter_id" do
    let!(:free_chapter) { create(:chapter, :free, book: ebook) }
    let!(:vip_chapter) { create(:chapter, :vip_only, book: ebook) }

    context "已登录" do
      it "获取免费章节内容" do
        get "/api/books/#{ebook.id}/chapters/#{free_chapter.id}", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data][:content]).to be_present
      end

      context "VIP 章节" do
        it "VIP 用户可以访问" do
          get "/api/books/#{ebook.id}/chapters/#{vip_chapter.id}", headers: vip_headers

          expect(response).to have_http_status(200)
          expect(json_response[:code]).to eq(0)
        end

        it "普通用户无法访问" do
          get "/api/books/#{ebook.id}/chapters/#{vip_chapter.id}", headers: headers

          expect(json_response[:code]).not_to eq(0)
        end
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/books/#{ebook.id}/chapters/#{free_chapter.id}"

        expect(response).to have_http_status(401)
      end
    end
  end
end
