# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Books Ebook", type: :request do
  describe "POST /api/books/export_epub" do
    let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 2, import_status: :ready) }

    it "accepts an EPUB export request and returns 202" do
      post "/api/books/export_epub",
           params: { book_id: book.id, pdf_oss_key: "pdfs/test-book.pdf" },
           as: :json

      expect(response).to have_http_status(202)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:book_id]).to eq(book.id)
      expect(json_response[:data][:message]).to include("EPUB 导出任务已提交")
    end

    it "returns 400 when book_id is missing" do
      post "/api/books/export_epub",
           params: { pdf_oss_key: "pdfs/test-book.pdf" },
           as: :json

      expect(response).to have_http_status(400)
    end

    it "accepts force_image_pages parameter" do
      post "/api/books/export_epub",
           params: { book_id: book.id, pdf_oss_key: "pdfs/test-book.pdf", force_image_pages: true },
           as: :json

      expect(response).to have_http_status(202)
      expect(json_response[:data][:message]).to include("EPUB 导出任务已提交")
    end
  end

  describe "GET /api/books/:id/pages" do
    let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 2, import_status: :ready) }
    let!(:page_one) { create(:ebook_page, book: book, page_number: 1, plain_text: "第一页内容") }
    let!(:page_two) { create(:ebook_page, book: book, page_number: 2, plain_text: "第二页内容") }

    it "returns the ebook page manifest" do
      get "/api/books/#{book.id}/pages"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:page_count]).to eq(2)
      expect(json_response[:data][:pages].map { |page| page[:page_number] }).to eq([1, 2])
      expect(json_response[:data][:pages].first[:directory]).to be_nil
    end
  end

  describe "GET /api/books/:id/pages/:page_number" do
    let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 1, import_status: :ready) }
    let!(:page) do
      create(
        :ebook_page,
        book: book,
        page_number: 1,
        plain_text: "[TITLE] 第一页标题\n[BODY] 第一页内容\n",
        rich_content: {
          text: "[TITLE] 第一页标题\n[BODY] 第一页内容\n",
           lines: [
             { id: "line-1", role: "heading", text: "第一页标题", marker: "[TITLE]", text_with_role: "[TITLE] 第一页标题\n", style: { font_family: "SourceHanSansCN-Bold", font_weight: "bold", font_style: "normal" } },
             { id: "line-2", role: "body", text: "第一页内容", marker: "[BODY]", text_with_role: "[BODY] 第一页内容\n", style: { font_family: "SourceHanSansCN-Regular", font_weight: "normal", font_style: "normal" } }
           ],
           images: [
             { id: "image-1", type: "image", role: "hero_image", image_url: "/system/ebooks/book_1/page_1/image_1.jpg" }
           ],
           directory: {
             title: "第一章 第一页标题",
             toc_page_number: 1,
             start_page_number: 1,
             level: 1,
             source: "toc"
           }
         }
       )
     end

    it "returns a single ebook page" do
      get "/api/books/#{book.id}/pages/1"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:page_number]).to eq(1)
      expect(json_response[:data][:text]).to eq("[TITLE] 第一页标题\n[BODY] 第一页内容\n")
      expect(json_response[:data][:lines].size).to eq(2)
      expect(json_response[:data][:images].first[:role]).to eq("hero_image")
      expect(json_response[:data][:directory][:title]).to eq("第一章 第一页标题")
    end
  end

  describe "GET /api/books/:id/pages/:page_number/html" do
    let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 1, import_status: :ready) }
    let!(:page) do
      create(
        :ebook_page,
        book: book,
        page_number: 1,
        plain_text: "第一页内容",
        xhtml_content: <<~XHTML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html>
          <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>测试页面</title></head>
            <body><p>第一页内容</p></body>
          </html>
        XHTML
      )
    end

    it "returns XHTML content" do
      get "/api/books/#{book.id}/pages/1/html"

      expect(response).to have_http_status(200)
      expect(response.body).to include("第一页内容")
      expect(response.body).to include("html")
    end

    it "returns 404 when page XHTML is not available" do
      page.update!(xhtml_content: nil)

      get "/api/books/#{book.id}/pages/1/html"

      expect(response).to have_http_status(404)
    end
  end

  describe "GET /api/books/:id/styles" do
    let(:book) { create(:book, status: :published, content_type: :ebook, styles_oss_url: "https://example.com/styles/book.css") }

    it "redirects to OSS styles URL" do
      get "/api/books/#{book.id}/styles"

      expect(response).to have_http_status(302)
      expect(response.headers["Location"]).to eq("https://example.com/styles/book.css")
    end

    it "returns 404 when styles are not available" do
      book.update!(styles_oss_url: nil)

      get "/api/books/#{book.id}/styles"

      expect(response).to have_http_status(404)
    end
  end

  describe "GET /api/books/:id/toc" do
    let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 2, import_status: :ready) }
    let!(:page_one) do
      create(:ebook_page, book: book, page_number: 1, plain_text: "第一页", rich_content: {
        "directory" => { "title" => "第一章 测试", "start_page_number" => 1, "level" => 1 }
      })
    end
    let!(:page_two) { create(:ebook_page, book: book, page_number: 2, plain_text: "第二页") }

    it "returns the table of contents" do
      get "/api/books/#{book.id}/toc"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data].size).to eq(1)
      expect(json_response[:data].first[:title]).to eq("第一章 测试")
      expect(json_response[:data].first[:start_page_number]).to eq(1)
      expect(json_response[:data].first[:level]).to eq(1)
    end

    it "returns empty array when no directories exist" do
      page_one.update!(rich_content: {})

      get "/api/books/#{book.id}/toc"

      expect(response).to have_http_status(200)
      expect(json_response[:data]).to eq([])
    end
  end

  describe "POST /api/books/import_epub" do
    let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 0, import_status: :not_imported) }

    it "accepts an EPUB import request and returns 202" do
      post "/api/books/import_epub",
           params: { book_id: book.id, epub_oss_key: "epubs/test-book.epub" },
           as: :json

      expect(response).to have_http_status(202)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:book_id]).to eq(book.id)
      expect(json_response[:data][:message]).to include("EPUB 导入任务已提交")
    end

    it "returns 400 when epub_oss_key is missing" do
      post "/api/books/import_epub",
           params: { book_id: book.id },
           as: :json

      expect(response).to have_http_status(400)
    end

    it "rejects non-epub files" do
      post "/api/books/import_epub",
           params: { book_id: book.id, epub_oss_key: "pdfs/test-book.pdf" },
           as: :json

      expect(response).to have_http_status(400)
    end

    it "uses epub filename as book title when title is blank" do
      post "/api/books/import_epub",
           params: { epub_oss_key: "小老虎历险记.epub" },
           as: :json

      expect(response).to have_http_status(202)
      book = Book.find(json_response[:data][:book_id])
      expect(book.title).to eq("小老虎历险记")
    end
  end

  describe "POST /api/books/import_pdf" do
    let(:files) { create_sample_ebook_pdf }

    after do
      cleanup_sample_ebook_pdf(files)
      FileUtils.rm_rf(Rails.root.join("public/system/ebooks"))
    end

    it "imports an uploaded pdf into ebook pages" do
      uploaded_file = Rack::Test::UploadedFile.new(files[:pdf].path, "application/pdf")

      post "/api/books/import_pdf",
           params: { title: "上传测试电子书", pdf: uploaded_file },
           as: :multipart

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:title]).to eq("上传测试电子书")

      book = Book.find(json_response[:data][:id])
      expect(book.page_count).to eq(2)
      expect(book.ebook_pages.count).to eq(2)
    end
  end
end
