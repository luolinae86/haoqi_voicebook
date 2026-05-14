# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Books", type: :request do
  let(:user) { create(:app_user) }
  let!(:book) { create(:book) }

  # ==================== 合集资源 ====================
  describe "GET /api/books/compilation" do
    it "返回合集下的所有资源" do
      compilation = create(:compilation)
      book1 = create(:book)
      book2 = create(:book)
      compilation.books << book1

      get "/api/books/compilation", params: { compilation_id: compilation.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:compilation][:id]).to eq(compilation.id)
      expect(data[:compilation][:name]).to eq(compilation.name)
      book_ids = data[:books].map { |b| b[:id] }
      expect(book_ids).to include(book1.id)
      expect(book_ids).not_to include(book2.id)
      expect(data[:contents]).to be_an(Array)
    end

    it "返回的 img_url 是签名后的 OSS 地址" do
      compilation = create(:compilation)
      book = create(:book)
      compilation.books << book

      get "/api/books/compilation", params: { compilation_id: compilation.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      data[:contents].each do |content|
        expect(content[:img_url]).to match(/\?Expires=/)
      end
    end

    it "合集不存在时返回 404" do
      get "/api/books/compilation", params: { compilation_id: 999999, uuid: user.uuid }

      expect(response).to have_http_status(404)
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/books/compilation", params: { compilation_id: 1 }

      expect(response).to have_http_status(400)
    end

    it "未提供 compilation_id 返回参数错误" do
      get "/api/books/compilation", params: { uuid: user.uuid }

      expect(response).to have_http_status(400)
    end

    it "无效 uuid 返回未授权" do
      get "/api/books/compilation", params: { compilation_id: 1, uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
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

    it "返回的 cover_image_url 是签名后的 OSS 地址" do
      create(:chapter, book: book, sn: 1, cover_image_url: "http://test.oss-cn-beijing.aliyuncs.com/cover.jpg")

      get "/api/books/#{book.id}/chapters", params: { uuid: user.uuid }

      chapters = json_response[:response][:data][:chapters]
      chapters.each do |chapter|
        expect(chapter[:cover_image_url]).to match(/\?Expires=/)
      end
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
