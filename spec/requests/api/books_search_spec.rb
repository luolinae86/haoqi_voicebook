# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Books Search", type: :request do
  let(:user) { create(:app_user) }
  let(:aliyun_oss_service) { instance_double(AliyunOssService) }

  before do
    allow(AliyunOssService).to receive(:new).and_return(aliyun_oss_service)
    allow(aliyun_oss_service).to receive(:generate_signed_url) do |object_key, **|
      "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}?OSSAccessKeyId=xxx&Expires=1234567890&Signature=yyy"
    end
  end

  # ==================== GET /api/books/search ====================
  describe "GET /api/books/search" do
    # -- 按书名搜索 --
    it "按书名模糊匹配返回结果" do
      author = create(:author, name: "鲁迅")
      create(:book, name: "西游记", author: author, play_count: 100)
      create(:book, name: "水浒传", author: author, play_count: 50)

      get "/api/books/search", params: { keyword: "西游", uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(1)
      expect(data[:books].first[:name]).to eq("西游记")
    end

    # -- 按作者名搜索 --
    it "按作者名模糊匹配返回结果" do
      author = create(:author, name: "曹文轩")
      create(:book, name: "草房子", author: author, play_count: 200)
      create(:book, name: "青铜葵花", author: author, play_count: 150)
      create(:book, name: "独立书籍", play_count: 300)

      get "/api/books/search", params: { keyword: "曹文轩", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(2)
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to contain_exactly("草房子", "青铜葵花")
    end

    # -- 按 content_type 过滤 --
    it "按内容类型过滤搜索结果" do
      author = create(:author)
      create(:book, name: "有声西游记", author: author, content_type: :audio, play_count: 100)
      create(:book, name: "视频西游记", author: author, content_type: :video, play_count: 200)
      create(:book, name: "图书西游记", author: author, content_type: :ebook, play_count: 300)

      get "/api/books/search", params: { keyword: "西游记", content_type: "audio", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(1)
      expect(data[:books].first[:name]).to eq("有声西游记")
      expect(data[:books].first[:content_type]).to eq("audio")
    end

    # -- 按热度排序 --
    it "搜索结果按 weekly_readers 和 play_count 降序排列" do
      author = create(:author)
      book1 = create(:book, name: "热门书", author: author, play_count: 10)
      create(:book_stats, book: book1, weekly_readers: 500)
      book2 = create(:book, name: "一般书", author: author, play_count: 200)
      create(:book_stats, book: book2, weekly_readers: 100)
      create(:book, name: "冷门书", author: author, play_count: 50)

      get "/api/books/search", params: { keyword: "书", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(3)
      expect(data[:books].map { |b| b[:name] }).to eq(["热门书", "一般书", "冷门书"])
    end

    # -- 封面 URL 签名 --
    it "返回签名后的封面 URL" do
      author = create(:author)
      create(:book, name: "封面书", author: author, cover_image_url: "https://bucket.oss-cn-beijing.aliyuncs.com/covers/test.jpg")

      get "/api/books/search", params: { keyword: "封面", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].first[:cover_image_url]).to match(/\?Expires=/)
    end

    # -- 未登录 --
    it "未提供 uuid 返回参数错误" do
      get "/api/books/search", params: { keyword: "测试" }

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 返回未授权" do
      get "/api/books/search", params: { keyword: "测试", uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    # -- 空关键词 --
    it "空关键词返回空结果" do
      get "/api/books/search", params: { keyword: "", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books]).to eq([])
      expect(data[:total_count]).to eq(0)
    end

    # -- 无结果 --
    it "无匹配结果返回空数组" do
      get "/api/books/search", params: { keyword: "不存在的书籍", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books]).to eq([])
      expect(data[:total_count]).to eq(0)
    end

    # -- 草稿书籍不出现 --
    it "不返回草稿状态的书籍" do
      author = create(:author)
      create(:book, name: "已发布书", author: author, status: :published)
      create(:book, name: "已发布书第二本", author: author, status: :draft)

      get "/api/books/search", params: { keyword: "已发布", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(1)
      expect(data[:books].first[:name]).to eq("已发布书")
    end
  end

  # ==================== GET /api/books/hot_search ====================
  describe "GET /api/books/hot_search" do
    it "返回按 sort_order 排序的活跃关键词" do
      create(:hot_search, keyword: "第一", sort_order: 3)
      create(:hot_search, keyword: "第二", sort_order: 1)
      create(:hot_search, keyword: "第三", sort_order: 2)

      get "/api/books/hot_search", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:keywords].map { |k| k[:keyword] }).to eq(["第二", "第三", "第一"])
    end

    it "不返回非活跃关键词" do
      create(:hot_search, keyword: "活跃词", is_active: true)
      create(:hot_search, keyword: "非活跃词", is_active: false)

      get "/api/books/hot_search", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      keywords = data[:keywords].map { |k| k[:keyword] }
      expect(keywords).to include("活跃词")
      expect(keywords).not_to include("非活跃词")
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/books/hot_search"

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 返回未授权" do
      get "/api/books/hot_search", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it "无数据时返回空数组" do
      get "/api/books/hot_search", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:keywords]).to eq([])
    end
  end
end
