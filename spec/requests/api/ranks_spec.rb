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
    it "返回用户年级的所有排行榜（按 category 分组）" do
      cat1 = create(:category, name: "文学")
      cat2 = create(:category, name: "漫画")
      Rank.create!(grade: grade, name: "必读榜单", sn: 1, category: cat1)
      Rank.create!(grade: grade, name: "推荐榜单", sn: 2, category: cat1)
      Rank.create!(grade: grade, name: "热门榜单", sn: 3, category: cat2)

      get "/api/ranks/", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      categories = json_response[:response][:data][:categories]
      expect(categories.size).to eq(2)
      # 文学分类
      lit_cat = categories.find { |c| c[:category_id] == cat1.id }
      expect(lit_cat[:category_name]).to eq("文学")
      expect(lit_cat[:ranks].size).to eq(2)
      expect(lit_cat[:ranks].first.keys).to match_array([:id, :name, :sn])
      # 漫画分类
      comic_cat = categories.find { |c| c[:category_id] == cat2.id }
      expect(comic_cat[:category_name]).to eq("漫画")
    end

    it "不返回其他年级的排行榜" do
      other_grade = create(:grade, name: "三年级")
      Rank.create!(grade: other_grade, name: "其他年级榜单", sn: 1, category: category)

      get "/api/ranks/", params: { uuid: user.uuid }

      categories = json_response[:response][:data][:categories]
      expect(categories).to eq([])
    end

    it "排行榜按 sn 升序排列" do
      Rank.create!(grade: grade, name: "第二", sn: 10, category: category)
      Rank.create!(grade: grade, name: "第一", sn: 1, category: category)

      get "/api/ranks/", params: { uuid: user.uuid }

      ranks = json_response[:response][:data][:categories].first[:ranks]
      expect(ranks.first[:name]).to eq("第一")
    end

    it "category_id 按升序排列" do
      cat1 = create(:category, name: "A类")
      cat2 = create(:category, name: "B类")
      Rank.create!(grade: grade, name: "榜单1", sn: 1, category: cat2)
      Rank.create!(grade: grade, name: "榜单2", sn: 1, category: cat1)

      get "/api/ranks/", params: { uuid: user.uuid }

      categories = json_response[:response][:data][:categories]
      expect(categories.map { |c| c[:category_id] }).to eq(categories.map { |c| c[:category_id] }.sort)
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
  describe "GET /api/ranks/by_id" do
    let!(:rank) { Rank.create!(grade: grade, name: "必读榜单", sn: 1, category: category) }
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

      get "/api/ranks/by_id", params: { rank_id: rank.id, uuid: user.uuid }

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

    it "返回图书的内容简介、出版社和二级分类" do
      supplier = Supplier.create!(name: "人民文学出版社")
      category_for_sub = Category.create!(name: "测试分类")
      sub = CategorySub.create!(name: "儿童文学", sn: 1, category: category_for_sub)
      book_with_details = Book.create!(
        name: "安徒生童话",
        cover_image_url: "https://example.com/cover.jpg",
        content_description: "经典童话合集",
        supplier: supplier
      )
      book_with_details.category_subs << sub
      RankContent.create!(rank: rank, content_type: "book", book: book_with_details, sn: 1)

      get "/api/ranks/by_id", params: { rank_id: rank.id, uuid: user.uuid }

      book_data = json_response[:response][:data][:contents].first[:book]
      expect(book_data[:content_description]).to eq("经典童话合集")
      expect(book_data[:supplier_name]).to eq("人民文学出版社")
      expect(book_data[:category_subs]).to eq([{ id: sub.id, name: "儿童文学", sn: 1 }])
    end

    it "返回合集信息" do
      RankContent.create!(rank: rank, content_type: "compilation", compilation: compilation, sn: 1)

      get "/api/ranks/by_id", params: { rank_id: rank.id, uuid: user.uuid }

      contents = json_response[:response][:data][:contents]
      expect(contents.first[:compilation][:name]).to eq("经典文学合集")
      expect(contents.first[:compilation][:total_count]).to eq(10)
    end

    it "内容按 sn 排序" do
      RankContent.create!(rank: rank, content_type: "book", book: book, sn: 10)
      RankContent.create!(rank: rank, content_type: "book", book: book, sn: 5)

      get "/api/ranks/by_id", params: { rank_id: rank.id, uuid: user.uuid }

      contents = json_response[:response][:data][:contents]
      sns = contents.map { |c| c[:sn] }
      expect(sns).to eq(sns.sort)
    end

    it "排行榜不属于当前用户年级时返回错误" do
      other_grade = create(:grade, name: "三年级")
      other_rank = Rank.create!(grade: other_grade, name: "其他年级", sn: 1, category: category)

      get "/api/ranks/by_id", params: { rank_id: other_rank.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it "排行榜不存在时返回错误" do
      get "/api/ranks/by_id", params: { rank_id: 999999, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it "空排行榜返回空数组" do
      get "/api/ranks/by_id", params: { rank_id: rank.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:contents]).to eq([])
    end
  end
end
