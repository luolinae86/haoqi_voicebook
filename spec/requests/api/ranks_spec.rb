# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Ranks", type: :request do
  let(:user) { create(:app_user) }
  let(:grade) { create(:grade, name: "二年级") }
  let(:category) { create(:category, name: "文学") }
  let(:aliyun_oss_service) { instance_double(AliyunOssService) }

  before do
    user.update_column(:grade_id, grade.id)
    allow(AliyunOssService).to receive(:new).and_return(aliyun_oss_service)
    allow(aliyun_oss_service).to receive(:generate_signed_url).and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/signed.jpg")
  end

  # ==================== 接口一：获取用户年级的排行榜列表 ====================
  describe "GET /api/ranks/" do
    it "返回用户年级的所有排行榜" do
      Rank.create!(grade: grade, name: "必读榜单", sn: 1)
      Rank.create!(grade: grade, name: "推荐榜单", sn: 2)

      get "/api/ranks/", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      ranks = json_response[:response][:data][:ranks]
      expect(ranks.size).to eq(2)
      expect(ranks.first.keys).to match_array([:id, :name, :sn, :category_id, :category_name])
    end

    it "不返回其他年级的排行榜" do
      other_grade = create(:grade, name: "三年级")
      Rank.create!(grade: other_grade, name: "其他年级榜单", sn: 1)

      get "/api/ranks/", params: { uuid: user.uuid }

      ranks = json_response[:response][:data][:ranks]
      expect(ranks).to eq([])
    end

    it "排行榜按 sn 升序排列" do
      Rank.create!(grade: grade, name: "第二", sn: 10)
      Rank.create!(grade: grade, name: "第一", sn: 1)

      get "/api/ranks/", params: { uuid: user.uuid }

      ranks = json_response[:response][:data][:ranks]
      expect(ranks.first[:name]).to eq("第一")
    end

    it "用户未设置年级时返回错误" do
      user.update_column(:grade_id, nil)

      get "/api/ranks/", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it "未登录时返回未授权错误" do
      get "/api/ranks/", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end
  end

  # ==================== 接口二：获取指定排行榜的内容 ====================
  describe "GET /api/ranks/:rank_id" do
    let!(:rank) { Rank.create!(grade: grade, name: "必读榜单", sn: 1) }
    let!(:book) do
      Book.create!(
        name: "小王子",
        cover_image_url: "https://example.com/book-cover.jpg",
        page_count: 50,
        word_count: 10000,
        rating: 4.5
      )
    end
    let!(:compilation) do
      Compilation.create!(
        name: "经典文学合集",
        banner_image_url: "https://example.com/banner.jpg",
        total_count: 10
      )
    end

    it "返回排行榜内容和图书信息" do
      RankContent.create!(rank: rank, content_type: "book", book: book, sn: 1)

      get "/api/ranks/#{rank.id}", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:rank][:name]).to eq("必读榜单")
      contents = data[:contents]
      expect(contents.size).to eq(1)
      expect(contents.first[:book][:name]).to eq("小王子")
      expect(contents.first[:book][:page_count]).to eq(50)
      expect(contents.first[:book][:cover_url]).to include("book-cover.jpg")
    end

    it "返回合集信息" do
      RankContent.create!(rank: rank, content_type: "compilation", compilation: compilation, sn: 1)

      get "/api/ranks/#{rank.id}", params: { uuid: user.uuid }

      contents = json_response[:response][:data][:contents]
      expect(contents.first[:compilation][:name]).to eq("经典文学合集")
      expect(contents.first[:compilation][:total_count]).to eq(10)
    end

    it "内容按 sn 排序" do
      RankContent.create!(rank: rank, content_type: "book", book: book, sn: 10)
      RankContent.create!(rank: rank, content_type: "book", book: book, sn: 5)

      get "/api/ranks/#{rank.id}", params: { uuid: user.uuid }

      contents = json_response[:response][:data][:contents]
      sns = contents.map { |c| c[:sn] }
      expect(sns).to eq(sns.sort)
    end

    it "排行榜不属于当前用户年级时返回错误" do
      other_grade = create(:grade, name: "三年级")
      other_rank = Rank.create!(grade: other_grade, name: "其他年级", sn: 1)

      get "/api/ranks/#{other_rank.id}", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it "排行榜不存在时返回错误" do
      get "/api/ranks/999999", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it "空排行榜返回空数组" do
      get "/api/ranks/#{rank.id}", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:contents]).to eq([])
    end
  end
end
