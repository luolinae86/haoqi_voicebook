# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Compilations", type: :request do
  let(:user) { create(:app_user) }
  let(:aliyun_oss_service) { instance_double(AliyunOssService) }

  before do
    allow(AliyunOssService).to receive(:new).and_return(aliyun_oss_service)
    allow(aliyun_oss_service).to receive(:generate_signed_url) do |object_key, **|
      "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}?OSSAccessKeyId=xxx&Expires=1234567890&Signature=yyy"
    end
  end

  describe "GET /api/compilations/:id" do
    let(:category) { Category.create!(name: "文学") }
    let!(:book1) { Book.create!(name: "小王子", cover_image_url: "https://example.com/book1.jpg", category: category) }
    let!(:book2) { Book.create!(name: "安徒生童话", cover_image_url: "https://example.com/book2.jpg", category: category) }
    let!(:compilation) do
      Compilation.create!(
        name: "经典文学合集",
        description: "精选经典文学作品",
        editor_recommendation: "经典推荐",
        total_count: 10,
        author: "安徒生",
        publisher: "人民文学出版社",
        landscape_cover_url: "https://example.com/cover.jpg"
      )
    end

    before do
      compilation.books << book1
      compilation.books << book2
    end

    it "返回合集详情及关联图书" do
      get "/api/compilations/by_id", params: { id: compilation.id, uuid: user.uuid }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      compilation_data = data[:compilation]
      expect(compilation_data[:name]).to eq("经典文学合集")
      expect(compilation_data[:description]).to eq("精选经典文学作品")
      expect(compilation_data[:editor_recommendation]).to eq("经典推荐")
      expect(compilation_data[:total_count]).to eq(10)
      expect(compilation_data[:author]).to eq("安徒生")
      expect(compilation_data[:publisher]).to eq("人民文学出版社")
    end

    it "返回的 cover_url 是签名后的 OSS 地址" do
      get "/api/compilations/by_id", params: { id: compilation.id, uuid: user.uuid }

      compilation_data = json_response[:response][:data][:compilation]
      expect(compilation_data[:cover_url]).to include("OSSAccessKeyId")
    end

    it "返回合集关联的图书列表" do
      get "/api/compilations/by_id", params: { id: compilation.id, uuid: user.uuid }

      books = json_response[:response][:data][:compilation][:books]
      expect(books.size).to eq(2)
      expect(books.map { |b| b[:name] }).to contain_exactly("小王子", "安徒生童话")
    end

    it "返回的图书 cover_url 是签名后的 OSS 地址" do
      get "/api/compilations/by_id", params: { id: compilation.id, uuid: user.uuid }

      books = json_response[:response][:data][:compilation][:books]
      books.each do |book|
        expect(book[:cover_url]).to include("OSSAccessKeyId")
      end
    end

    it "合集没有关联图书时返回空数组" do
      empty_compilation = Compilation.create!(name: "空合集", total_count: 0)

      get "/api/compilations/by_id", params: { id: empty_compilation.id, uuid: user.uuid }

      expect(response).to have_http_status(:success)
      books = json_response[:response][:data][:compilation][:books]
      expect(books).to eq([])
    end

    it "合集不存在时返回错误" do
      get "/api/compilations/by_id", params: { id: 999999, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it "未提供 uuid 时返回参数错误" do
      get "/api/compilations/by_id", params: { id: compilation.id }

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 时返回未授权错误" do
      get "/api/compilations/by_id", params: { id: compilation.id, uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end
end
