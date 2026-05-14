# frozen_string_literal: true

require "rails_helper"
require "prawn"
require "tempfile"

RSpec.describe "API Chapters", type: :request do
  let(:user) { create(:app_user) }
  let(:book) { create(:book, status: :published, content_type: :ebook) }
  let(:chapter) do
    create(:chapter, book: book, content_file_type: "pdf", content_file_url: "http://zheli.oss-cn-beijing.aliyuncs.com/test-chapter.pdf", content_file_name: "test.pdf", is_published: true)
  end
  let(:oss_service) { instance_double(AliyunOssService) }

  after do
    FileUtils.rm_rf(Rails.public_path.join("system/ebooks"))
  end

  def create_test_pdf(path)
    Prawn::Document.generate(path, margin: 48) do |pdf|
      pdf.font_size 24
      pdf.text "Chapter 1", align: :center
      pdf.move_down 18
      pdf.font_size 12
      pdf.text "This is the first page body content for importer verification."
    end
  end

  # ==================== 导出章节 EPUB ====================
  describe "POST /api/chapters/export_epub" do
    it "提交 EPUB 导出任务" do
      post "/api/chapters/export_epub", params: {
        uuid: user.uuid,
        chapter_id: chapter.id
      }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:chapter_id]).to eq(chapter.id)
    end

    it "未登录时返回未授权错误" do
      post "/api/chapters/export_epub", params: {
        chapter_id: chapter.id
      }

      expect([400, 401]).to include(response.status)
      body = json_response
      expect(body[:response][:code]).to be > 0 if body[:response]
    end

    it "章节没有 PDF 文件时返回错误" do
      no_pdf_chapter = create(:chapter, book: book, content_file_type: "epub", content_file_url: nil, is_published: true)

      post "/api/chapters/export_epub", params: {
        uuid: user.uuid,
        chapter_id: no_pdf_chapter.id
      }

      expect([400, 200]).to include(response.status)
      body = json_response
      if body[:response]
        expect(body[:response][:code]).to be > 0
      end
    end

    it "章节不存在时返回错误" do
      post "/api/chapters/export_epub", params: {
        uuid: user.uuid,
        chapter_id: 999_999
      }

      expect([404, 500]).to include(response.status)
    end
  end

  # ==================== 查询 EPUB 状态 ====================
  describe "GET /api/chapters/:id/epub_status" do
    it "返回章节 EPUB 导出状态" do
      chapter.update!(epub_export_status: :completed, epub_oss_url: "https://example.com/test.epub")

      get "/api/chapters/#{chapter.id}/epub_status", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:chapter_id]).to eq(chapter.id)
      expect(json_response[:response][:data][:epub_export_status]).to eq("completed")
      expect(json_response[:response][:data][:epub_oss_url]).to include(".epub")
    end

    it "未导出状态返回 not_exported" do
      get "/api/chapters/#{chapter.id}/epub_status", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:epub_export_status]).to eq("not_exported")
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/chapters/#{chapter.id}/epub_status"

      expect(response).to have_http_status(400)
    end

    it "无效 uuid 时返回未授权错误" do
      get "/api/chapters/#{chapter.id}/epub_status", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 页面清单 ====================
  describe "GET /api/chapters/:id/pages" do
    it "返回章节页面清单" do
      page = book.ebook_pages.create!(page_number: 1, page_width: 800, page_height: 600, rich_content: {})
      page.update!(chapter_id: chapter.id)

      get "/api/chapters/#{chapter.id}/pages", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:chapter_id]).to eq(chapter.id)
      expect(json_response[:response][:data][:pages]).to be_an(Array)
    end

    it "没有页面时返回空数组" do
      get "/api/chapters/#{chapter.id}/pages", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:pages]).to eq([])
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/chapters/#{chapter.id}/pages"

      expect(response).to have_http_status(400)
    end

    it "无效 uuid 时返回未授权错误" do
      get "/api/chapters/#{chapter.id}/pages", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 页面内容 ====================
  describe "GET /api/chapters/:id/pages/:page_number" do
    it "返回章节单页内容" do
      page1 = book.ebook_pages.create!(page_number: 1, page_width: 800, page_height: 600, rich_content: { "text" => "test", "lines" => [], "images" => [], "directory" => nil }, plain_text: "test content")
      page2 = book.ebook_pages.create!(page_number: 2, page_width: 800, page_height: 600, rich_content: { "text" => "test2", "lines" => [], "images" => [], "directory" => nil }, plain_text: "test content 2")
      page1.update!(chapter_id: chapter.id)
      page2.update!(chapter_id: chapter.id)

      get "/api/chapters/#{chapter.id}/pages/1", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:chapter_id]).to eq(chapter.id)
      expect(data[:page_number]).to eq(1)
    end

    it "返回的图片 URL 已签名" do
      page = book.ebook_pages.create!(page_number: 1, page_width: 800, page_height: 600, rich_content: { "text" => "test", "lines" => [], "images" => [{ "id" => "image-1-1", "image_url" => "https://bucket.oss-cn-beijing.aliyuncs.com/test.png" }], "directory" => nil }, plain_text: "test content")
      page.update!(chapter_id: chapter.id)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:generate_signed_url).and_return("https://bucket.oss-cn-beijing.aliyuncs.com/test.png?Expires=1234567890&Signature=xxx")

      get "/api/chapters/#{chapter.id}/pages/1", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      images = json_response[:response][:data][:images]
      expect(images.first[:image_url]).to include("Signature=")
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/chapters/#{chapter.id}/pages/1"

      expect(response).to have_http_status(400)
    end
  end

  # ==================== 页面 XHTML 内容 ====================
  describe "GET /api/chapters/:id/pages/:page_number/html" do
    it "返回单页 XHTML 内容" do
      page = book.ebook_pages.create!(page_number: 1, page_width: 800, page_height: 600, rich_content: {}, xhtml_content: "<html><body>Test</body></html>")
      page.update!(chapter_id: chapter.id)

      get "/api/chapters/#{chapter.id}/pages/1/html", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(response.body).to include("Test")
    end

    it "XHTML 中的 OSS URL 已签名" do
      chapter.update!(styles_oss_url: "https://bucket.oss-cn-beijing.aliyuncs.com/styles/book.css")
      page = book.ebook_pages.create!(page_number: 1, page_width: 800, page_height: 600, rich_content: {}, xhtml_content: "<html><head><link href=\"https://bucket.oss-cn-beijing.aliyuncs.com/styles/book.css\" /></head><body>Test</body></html>")
      page.update!(chapter_id: chapter.id)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:generate_signed_url).and_return("https://bucket.oss-cn-beijing.aliyuncs.com/styles/book.css?Expires=1234567890&Signature=xxx")

      get "/api/chapters/#{chapter.id}/pages/1/html", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(response.body).to include("Signature=")
      expect(response.body).not_to include("https://bucket.oss-cn-beijing.aliyuncs.com/styles/book.css\"")
    end

    it "XHTML 未导出时返回 404" do
      page = book.ebook_pages.create!(page_number: 1, page_width: 800, page_height: 600, rich_content: {})
      page.update!(chapter_id: chapter.id)

      get "/api/chapters/#{chapter.id}/pages/1/html", params: { uuid: user.uuid }

      expect(response).to have_http_status(404)
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/chapters/#{chapter.id}/pages/1/html"

      expect(response).to have_http_status(400)
    end
  end

  # ==================== 样式表 ====================
  describe "GET /api/chapters/:id/styles" do
    it "重定向到样式表 URL" do
      chapter.update!(styles_oss_url: "https://example.com/book.css")

      get "/api/chapters/#{chapter.id}/styles", params: { uuid: user.uuid }

      expect(response).to be_redirect
    end

    it "样式表未导出时返回 404" do
      get "/api/chapters/#{chapter.id}/styles", params: { uuid: user.uuid }

      expect(response).to have_http_status(404)
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/chapters/#{chapter.id}/styles"

      expect(response).to have_http_status(400)
    end
  end

  # ==================== 完整导出流程 ====================
  describe "完整 EPUB 导出流程" do
    it "从章节 PDF 生成 EPUB 并保存页面" do
      # Create a real PDF that the worker will "download"
      fake_pdf = Tempfile.new(["source", ".pdf"])
      create_test_pdf(fake_pdf.path)

      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:download_file) do |object_key:, local_path:|
        FileUtils.cp(fake_pdf.path, local_path)
      end
      allow(oss_service).to receive(:upload_data).and_return("https://example.com/test.png")
      allow(oss_service).to receive(:upload_file) do |object_key:, **|
        "https://example.com/#{object_key}"
      end

      ChapterEpubExportWorker.new.perform({
                                            "chapter_id" => chapter.id,
                                            "force_image_pages" => false
                                          })

      chapter.reload
      expect(chapter.epub_export_status).to eq("completed")
      expect(chapter.epub_oss_url).to include(".epub")
      expect(chapter.epub_export_error).to be_nil
      expect(chapter.styles_oss_url).to include("book.css")
      expect(chapter.nav_oss_url).to include("nav.xhtml")
      expect(chapter.ebook_pages.count).to be > 0
      expect(chapter.ebook_pages.first.xhtml_content).to include("book.css")

      fake_pdf.close!
    end

    it "导出失败时记录错误信息" do
      allow(AliyunOssService).to receive(:new).and_raise(AliyunOssService::UploadError, "OSS 连接失败")

      expect do
        ChapterEpubExportWorker.new.perform({
                                              "chapter_id" => chapter.id,
                                              "force_image_pages" => false
                                            })
      end.to raise_error(AliyunOssService::UploadError)

      chapter.reload
      expect(chapter.epub_export_status).to eq("export_failed")
      expect(chapter.epub_export_error).to include("OSS 连接失败")
    end
  end
end
