# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Books", type: :request do
  let(:user) { create(:app_user) }
  let!(:book) { create(:book) }

  # ==================== 图书列表 ====================
  describe "GET /api/books" do
    it "返回图书列表" do
      get "/api/books"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:books]).to be_an(Array)
    end

    it "支持分页" do
      get "/api/books", params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:books].size).to be <= 2
    end

    it "按合集筛选" do
      compilation = create(:compilation)
      book1 = create(:book)
      book2 = create(:book)
      compilation.books << book1

      get "/api/books", params: { compilation_id: compilation.id }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data][:books]
      book_ids = data.map { |b| b[:id] }
      expect(book_ids).to include(book1.id)
      expect(book_ids).not_to include(book2.id)
    end

    it "合集不存在时返回 404" do
      get "/api/books", params: { compilation_id: 999999 }

      expect(response).to have_http_status(404)
    end

    it "只返回已发布的图书" do
      draft_book = create(:book, status: "draft")
      offline_book = create(:book, status: "offline")

      get "/api/books"

      book_ids = json_response[:response][:data][:books].map { |b| b[:id] }
      expect(book_ids).not_to include(draft_book.id)
      expect(book_ids).not_to include(offline_book.id)
    end
  end

  # ==================== 图书详情 ====================
  describe "GET /api/books/:id" do
    it "返回图书详情" do
      get "/api/books/#{book.id}", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:book][:id]).to eq(book.id)
      expect(json_response[:response][:data][:book][:name]).to eq(book.name)
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/#{book.id}"

      expect(response).to have_http_status(400)
    end

    it "无效 uuid 时返回未授权错误" do
      get "/api/books/#{book.id}", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it "图书不存在时返回 404" do
      get "/api/books/999999", params: { uuid: user.uuid }

      expect(response).to have_http_status(404)
    end

    it "未发布的图书返回 404" do
      draft_book = create(:book, status: "draft")

      get "/api/books/#{draft_book.id}", params: { uuid: user.uuid }

      expect(response).to have_http_status(404)
    end
  end

  # ==================== 图书章节列表 ====================
  describe "GET /api/books/:id/chapters" do
    it "返回章节列表" do
      chapter1 = create(:chapter, book: book, sn: 1)
      chapter2 = create(:chapter, book: book, sn: 2)

      get "/api/books/#{book.id}/chapters", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      chapters = json_response[:response][:data][:chapters]
      expect(chapters.size).to eq(2)
      expect(chapters.map { |c| c[:id] }).to contain_exactly(chapter1.id, chapter2.id)
    end

    it "按 sn 排序" do
      create(:chapter, book: book, sn: 3)
      create(:chapter, book: book, sn: 1)
      create(:chapter, book: book, sn: 2)

      get "/api/books/#{book.id}/chapters", params: { uuid: user.uuid }

      chapters = json_response[:response][:data][:chapters]
      expect(chapters.map { |c| c[:sn] }).to eq([1, 2, 3])
    end

    it "没有章节时返回空数组" do
      get "/api/books/#{book.id}/chapters", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:chapters]).to eq([])
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/#{book.id}/chapters"

      expect(response).to have_http_status(400)
    end

    it "图书不存在时返回 404" do
      get "/api/books/999999/chapters", params: { uuid: user.uuid }

      expect(response).to have_http_status(404)
    end
  end
end
