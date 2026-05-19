# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Books", type: :request do
  let(:user) { create(:app_user) }
  let!(:book) { create(:book) }

  # ==================== 合集资源 ====================
  describe "GET /api/books/compilation" do
    it "返回合集下的所有资源" do
      compilation = create(:compilation)
      book1 = create(:book, content_description: "合集中的第一本书简介")
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
      # 验证合集中的书籍返回 content_description
      book1_data = data[:books].find { |b| b[:id] == book1.id }
      expect(book1_data[:content_description]).to eq("合集中的第一本书简介")
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

      expect(response).to have_http_status(200)
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/books/compilation", params: { compilation_id: 1 }

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 返回未授权" do
      get "/api/books/compilation", params: { compilation_id: 1, uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 图书详情 ====================
  describe "GET /api/books/by_id" do
    it "返回图书详情" do
      get "/api/books/by_id", params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:book][:id]).to eq(book.id)
      expect(json_response[:response][:data][:book][:name]).to eq(book.name)
    end

    it "返回图书简介 content_description" do
      book.update!(content_description: "这是一本精彩的书籍简介")

      get "/api/books/by_id", params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:book][:content_description]).to eq("这是一本精彩的书籍简介")
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/by_id", params: { id: book.id }

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 时返回未授权错误" do
      get "/api/books/by_id", params: { id: book.id, uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it "图书不存在时返回 404" do
      get "/api/books/by_id", params: { id: 999999, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 章节目录 ====================
  describe "GET /api/books/chapters" do
    it "返回章节目录" do
      create(:book_chapter, book: book, chapter_number: 1, chapter_name: '第一章', start_page_number: 1, word_count: 1200)
      create(:book_chapter, book: book, chapter_number: 2, chapter_name: '第二章', start_page_number: 10, word_count: 2500)

      get "/api/books/chapters", params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      chapters = json_response[:response][:data][:chapters]
      expect(chapters.size).to eq(2)
      expect(chapters.first[:chapter_name]).to eq('第一章')
      expect(chapters.first).to have_key(:is_free)
      expect(chapters.first[:word_count]).to eq(1200)
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/chapters", params: { id: book.id }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 导入电子书 ====================
  describe "POST /api/books/import" do
    it "提交 PDF 导入任务" do
      book.update!(content_file_url: "https://bucket.oss-cn-beijing.aliyuncs.com/test/book.pdf")

      post "/api/books/import", params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(201)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to eq(0)
      expect(body[:response][:data][:book_id]).to eq(book.id)
      expect(body[:response][:data][:content_file_type]).to eq("pdf")
    end

    it "提交 EPUB 导入任务" do
      book.update!(content_file_url: "https://bucket.oss-cn-beijing.aliyuncs.com/test/book.epub")

      post "/api/books/import", params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(201)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to eq(0)
      expect(body[:response][:data][:content_file_type]).to eq("epub")
    end

    it "使用图书的 content_file_url 进行导入" do
      book.update!(content_file_url: "https://bucket.oss-cn-beijing.aliyuncs.com/test/book.pdf")

      post "/api/books/import", params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(201)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to eq(0)
      expect(body[:response][:data][:book_id]).to eq(book.id)
    end

    it "图书没有 file_url 时返回错误" do
      book.update!(content_file_url: nil)

      post "/api/books/import", params: {
        uuid: user.uuid,
        id: book.id
      }

      expect(response).to have_http_status(200)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to be > 0
    end

    it "未提供 uuid 时返回参数错误" do
      post "/api/books/import", params: {
        id: book.id
      }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 页面清单 ====================
  describe "GET /api/books/pages" do
    it "返回图书页面清单" do
      page1 = create(:ebook_page, :pdf_image, book: book, page_number: 1)
      page2 = create(:ebook_page, :pdf_image, book: book, page_number: 2)

      get "/api/books/pages", params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:book_id]).to eq(book.id)
      expect(json_response[:response][:data][:pages]).to be_an(Array)
      expect(json_response[:response][:data][:pages].size).to eq(2)
    end

    it "没有页面时返回空数组" do
      get "/api/books/pages", params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:pages]).to eq([])
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/pages", params: { id: book.id }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 单页内容 ====================
  describe "GET /api/books/page" do
    it "返回 PDF 图片页内容" do
      page = create(:ebook_page, :pdf_image, book: book, page_number: 1)

      get "/api/books/page", params: { id: book.id, page_number: 1, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:book_id]).to eq(book.id)
      expect(data[:page_number]).to eq(1)
      expect(data[:image_url]).to include("Signature=")
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/page", params: { id: book.id, page_number: 1 }

      expect(response).to have_http_status(200)
    end

    it "页面不存在时返回 404" do
      get "/api/books/page", params: { id: book.id, page_number: 999, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 页面 XHTML 内容 ====================
  describe "GET /api/books/page_html" do
    it "返回 EPUB 页 XHTML 内容" do
      page = create(:ebook_page, :epub, book: book, page_number: 1,
                    xhtml_content: "<html><body><p>Test Content</p></body></html>")

      get "/api/books/page_html", params: { id: book.id, page_number: 1, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(response.body).to include("Test Content")
    end

    it "XHTML 未导出时返回 404" do
      page = create(:ebook_page, :pdf_image, book: book, page_number: 1)

      get "/api/books/page_html", params: { id: book.id, page_number: 1, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/page_html", params: { id: book.id, page_number: 1 }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 样式表 ====================
  describe "GET /api/books/styles" do
    it "重定向到样式表 URL" do
      book.update!(styles_oss_url: "https://bucket.oss-cn-beijing.aliyuncs.com/styles/book.css")

      get "/api/books/styles", params: { id: book.id, uuid: user.uuid }

      expect(response).to be_redirect
    end

    it "样式表未导出时返回 404" do
      get "/api/books/styles", params: { id: book.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/books/styles", params: { id: book.id }

      expect(response).to have_http_status(200)
    end
  end
end
