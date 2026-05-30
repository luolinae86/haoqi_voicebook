# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Category Browse", type: :request do
  let(:user) { create(:app_user) }
  let(:grade) { create(:grade, name: "二年级") }

  # 一级分类：图书（picture_book），听书（audio）
  let(:book_category) { create(:category, name: "图书", level: 1, sn: 1) }
  let(:audio_category) { create(:category, name: "听书", level: 1, sn: 2) }

  # 二级分类
  let(:school_recommended) { create(:category_sub, name: "学校推荐", category: book_category, sn: 1) }
  let(:essay) { create(:category_sub, name: "作文", category: book_category, sn: 2) }
  let(:english) { create(:category_sub, name: "英语", category: book_category, sn: 3) }

  before do
    user.update_column(:grade_id, grade.id)
  end

  # ==================== 接口一：获取二级分类列表 ====================
  describe "GET /api/categories/subs" do
    before do
      # 创建图书以关联二级分类
      b = create(:book, name: "测试图书", content_type: :picture_book)
      b.grades << grade
      b.category_subs << school_recommended
      b.category_subs << essay
      b.category_subs << english
    end

    it "返回二级分类列表" do
      get "/api/categories/subs", params: { grade_id: grade.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      subs = json_response[:response][:data][:category_subs]
      expect(subs.size).to eq(3)
      expect(subs.map { |s| s[:name] }).to match_array(["学校推荐", "作文", "英语"])
    end

    it "按 sn 排序" do
      get "/api/categories/subs", params: { grade_id: grade.id, uuid: user.uuid }

      subs = json_response[:response][:data][:category_subs]
      sns = subs.map { |s| s[:sn] }
      expect(sns).to eq(sns.sort)
    end

    it "未登录时返回错误" do
      get "/api/categories/subs", params: { grade_id: grade.id, uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end
  end

  # ==================== 接口二：分类浏览 ====================
  describe "GET /api/categories/browse" do
    let!(:book1) do
      b = create(:book, name: "小王子", content_type: :picture_book, play_count: 100)
      b.grades << grade
      b.category_subs << school_recommended
      b
    end
    let!(:book2) do
      b = create(:book, name: "安徒生童话", content_type: :picture_book, play_count: 50)
      b.grades << grade
      b.category_subs << school_recommended
      b
    end
    let!(:book3) do
      b = create(:book, name: "英语入门", content_type: :picture_book, play_count: 200)
      b.grades << grade
      b.category_subs << english
      b
    end
    let!(:book_other_grade) do
      b = create(:book, name: "其他年级的书", content_type: :picture_book, play_count: 300)
      b.grades << create(:grade, name: "三年级")
      b.category_subs << school_recommended
      b
    end

    it "按年级和内容类型返回图书（按热度排序）" do
      get "/api/categories/browse", params: { grade_id: grade.id, content_type: "picture_book", uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      books = json_response[:response][:data][:books]
      # book3 (200) > book1 (100) > book2 (50)
      expect(books.first[:name]).to eq("英语入门")
      expect(books[1][:name]).to eq("小王子")
      expect(books[2][:name]).to eq("安徒生童话")
    end

    it "按二级分类筛选" do
      get "/api/categories/browse", params: {
        grade_id: grade.id,
        content_type: "picture_book",
        category_sub_id: english.id,
        uuid: user.uuid
      }

      books = json_response[:response][:data][:books]
      expect(books.size).to eq(1)
      expect(books.first[:name]).to eq("英语入门")
    end

    it "不返回其他年级的图书" do
      get "/api/categories/browse", params: { grade_id: grade.id, content_type: "picture_book", uuid: user.uuid }

      book_names = json_response[:response][:data][:books].map { |b| b[:name] }
      expect(book_names).not_to include("其他年级的书")
    end

    it "分页返回数据" do
      get "/api/categories/browse", params: {
        grade_id: grade.id,
        content_type: "picture_book",
        page: 1,
        per_page: 2,
        uuid: user.uuid
      }

      pagination = json_response[:response][:data][:pagination]
      expect(pagination[:total]).to eq(3)
      expect(pagination[:per_page]).to eq(2)
      expect(json_response[:response][:data][:books].size).to eq(2)
    end

    it "返回图书基本信息（含出版社、内容简介、二级分类）" do
      get "/api/categories/browse", params: {
        grade_id: grade.id,
        content_type: "picture_book",
        uuid: user.uuid
      }

      book = json_response[:response][:data][:books].first
      expect(book).to have_key(:content_description)
      expect(book).to have_key(:supplier_name)
      expect(book).to have_key(:category_subs)
    end

    it "未登录时返回错误" do
      get "/api/categories/browse", params: { grade_id: grade.id, content_type: "picture_book", uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end
  end
end
