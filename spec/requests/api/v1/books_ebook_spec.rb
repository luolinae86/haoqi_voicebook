# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Books Ebook", type: :request do
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
