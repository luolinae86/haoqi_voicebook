# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Blacklist Filtering", type: :request do
  let(:user) { create(:app_user) }
  let(:parental_control) { create(:parental_control, app_user: user) }
  let(:auth_params) { { uuid: user.uuid } }

  # 创建测试图书
  let!(:clean_book) { create(:book, name: "好书", status: :published) }
  let!(:blacklisted_book_record) { create(:book, name: "坏书", status: :published) }

  before do
    # 将坏书加入黑名单
    BlacklistedBook.create!(parental_control: parental_control, book: blacklisted_book_record)
  end

  # ==================== Book Model Scope ====================
  describe "Book.not_in_blacklist" do
    it "排除黑名单中的图书" do
      result = Book.not_in_blacklist(user.id).pluck(:id)
      expect(result).to include(clean_book.id)
      expect(result).not_to include(blacklisted_book_record.id)
    end

    it "无黑名单时返回所有图书" do
      parental_control.blacklisted_books.destroy_all
      result = Book.not_in_blacklist(user.id).pluck(:id)
      expect(result).to include(clean_book.id, blacklisted_book_record.id)
    end

    it "无家长管控时返回所有图书" do
      parental_control.destroy
      result = Book.not_in_blacklist(user.id).pluck(:id)
      expect(result).to include(clean_book.id, blacklisted_book_record.id)
    end
  end

  # ==================== 搜索接口 ====================
  describe "GET /api/books/search" do
    it "搜索结果不包含黑名单中的图书" do
      get "/api/books/search", params: auth_params.merge(keyword: "书")

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      books = json_response[:response][:data][:books]
      book_ids = books.map { |b| b[:id] }
      expect(book_ids).to include(clean_book.id)
      expect(book_ids).not_to include(blacklisted_book_record.id)
    end
  end

  # ==================== 按作者查询 ====================
  describe "GET /api/books/by_author" do
    let!(:author) { create(:author) }

    before do
      clean_book.update!(author: author)
      blacklisted_book_record.update!(author: author)
    end

    it "按作者查询不包含黑名单中的图书" do
      get "/api/books/by_author", params: auth_params.merge(author_id: author.id)

      expect(response).to have_http_status(200)
      books = json_response[:response][:data][:books]
      book_ids = books.map { |b| b[:id] }
      expect(book_ids).to include(clean_book.id)
      expect(book_ids).not_to include(blacklisted_book_record.id)
    end
  end

  # ==================== 排行榜 ====================
  describe "GET /api/books/leaderboard" do
    it "排行榜不包含黑名单中的图书" do
      get "/api/books/leaderboard", params: auth_params.merge(ranking_type: "hot")

      expect(response).to have_http_status(200)
      books = json_response[:response][:data][:books]
      book_ids = books.map { |b| b[:id] }
      expect(book_ids).not_to include(blacklisted_book_record.id)
    end
  end

  # ==================== 热搜榜单 ====================
  describe "GET /api/books/hot_search" do
    let!(:category) { create(:category) }

    before do
      clean_book.update!(category: category)
      blacklisted_book_record.update!(category: category)
    end

    it "热搜榜单不包含黑名单中的图书" do
      get "/api/books/hot_search", params: auth_params.merge(category_id: category.id, ranking_type: "hot")

      expect(response).to have_http_status(200)
      books = json_response[:response][:data][:books]
      book_ids = books.map { |b| b[:id] }
      expect(book_ids).not_to include(blacklisted_book_record.id)
    end
  end

  # ==================== 图书详情 ====================
  describe "GET /api/books/by_id" do
    it "查看黑名单中的图书返回错误" do
      get "/api/books/by_id", params: auth_params.merge(id: blacklisted_book_record.id)

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
      expect(json_response[:response][:msg]).to include("黑名单")
    end

    it "查看非黑名单中的图书正常返回" do
      get "/api/books/by_id", params: auth_params.merge(id: clean_book.id)

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:book][:id]).to eq(clean_book.id)
    end
  end

  # ==================== 图书目录 ====================
  describe "GET /api/books/catalogue" do
    it "查看黑名单图书的目录返回错误" do
      get "/api/books/catalogue", params: auth_params.merge(id: blacklisted_book_record.id)

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 图书页面 ====================
  describe "GET /api/books/pages" do
    it "查看黑名单图书的页面列表返回错误" do
      get "/api/books/pages", params: auth_params.merge(id: blacklisted_book_record.id)

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 图书单页 ====================
  describe "GET /api/books/page" do
    it "查看黑名单图书的单页返回错误" do
      get "/api/books/page", params: auth_params.merge(id: blacklisted_book_record.id, page_number: 1)

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 图书 XHTML ====================
  describe "GET /api/books/page_html" do
    it "查看黑名单图书的 XHTML 返回错误" do
      get "/api/books/page_html", params: auth_params.merge(id: blacklisted_book_record.id, page_number: 1)

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 图书样式表 ====================
  describe "GET /api/books/styles" do
    it "查看黑名单图书的样式表返回错误" do
      get "/api/books/styles", params: auth_params.merge(id: blacklisted_book_record.id)

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 首页推荐详情 ====================
  describe "GET /api/home/recommends/by_recommend_id" do
    let(:grade) { create(:grade) }
    let!(:recommend) { Recommend.create!(grade: grade, name: "推荐", status: true) }
    let!(:content_group) do
      ContentGroup.create!(recommend: recommend, name: "图书分组", group_type: "one_row_three_columns", sn: 0)
    end

    before do
      user.update_column(:grade_id, grade.id)
      Content.create!(content_group: content_group, content_type: "book", book: clean_book, sn: 0)
      Content.create!(content_group: content_group, content_type: "book", book: blacklisted_book_record, sn: 1)
    end

    it "首页推荐内容过滤黑名单图书" do
      get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      content_groups = json_response[:response][:data][:content_groups]
      contents = content_groups.first[:contents]
      content_book_ids = contents.select { |c| c[:content_type] == "book" }.map { |c| c[:book][:id] }
      expect(content_book_ids).to include(clean_book.id)
      expect(content_book_ids).not_to include(blacklisted_book_record.id)
    end

    it "非黑名单图书正常显示" do
      # 移除黑名单
      parental_control.blacklisted_books.destroy_all

      get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

      content_groups = json_response[:response][:data][:content_groups]
      contents = content_groups.first[:contents]
      content_book_ids = contents.select { |c| c[:content_type] == "book" }.map { |c| c[:book][:id] }
      expect(content_book_ids).to include(clean_book.id, blacklisted_book_record.id)
    end
  end

  # ==================== 合集详情 ====================
  describe "GET /api/compilations/by_id" do
    let!(:compilation) { create(:compilation) }

    before do
      compilation.books << clean_book
      compilation.books << blacklisted_book_record
    end

    it "合集详情过滤黑名单图书" do
      get "/api/compilations/by_id", params: auth_params.merge(id: compilation.id)

      expect(response).to have_http_status(200)
      books = json_response[:response][:data][:compilation][:books]
      book_ids = books.map { |b| b[:id] }
      expect(book_ids).to include(clean_book.id)
      expect(book_ids).not_to include(blacklisted_book_record.id)
    end
  end

  # ==================== 合集资源（books 接口） ====================
  describe "GET /api/books/compilation" do
    let!(:compilation) { create(:compilation) }

    before do
      compilation.books << clean_book
      compilation.books << blacklisted_book_record
    end

    it "合集资源过滤黑名单图书" do
      get "/api/books/compilation", params: auth_params.merge(compilation_id: compilation.id)

      expect(response).to have_http_status(200)
      books = json_response[:response][:data][:books]
      book_ids = books.map { |b| b[:id] }
      expect(book_ids).to include(clean_book.id)
      expect(book_ids).not_to include(blacklisted_book_record.id)
    end
  end

  # ==================== 排行榜内容 ====================
  describe "GET /api/ranks/by_id" do
    let(:grade) { create(:grade) }
    let!(:category) { create(:category) }
    let!(:rank) { Rank.create!(grade: grade, category: category, name: "排行", sn: 1) }

    before do
      user.update_column(:grade_id, grade.id)
      RankContent.create!(rank: rank, content_type: "book", book: clean_book, sn: 0)
      RankContent.create!(rank: rank, content_type: "book", book: blacklisted_book_record, sn: 1)
    end

    it "排行榜内容过滤黑名单图书" do
      get "/api/ranks/by_id", params: { rank_id: rank.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      contents = json_response[:response][:data][:rank][:contents] || json_response[:response][:data][:contents]
      if contents.present?
        book_ids = contents.select { |c| c[:content_type] == "book" && c[:book].present? }.map { |c| c[:book][:id] }
        expect(book_ids).not_to include(blacklisted_book_record.id)
      end
    end
  end

  # ==================== 其他用户不受影响 ====================
  describe "跨用户隔离" do
    let!(:other_user) { create(:app_user) }
    let!(:other_auth_params) { { uuid: other_user.uuid } }

    it "其他用户可以正常看到被加入黑名单的图书" do
      get "/api/books/search", params: other_auth_params.merge(keyword: "书")

      expect(response).to have_http_status(200)
      books = json_response[:response][:data][:books]
      book_ids = books.map { |b| b[:id] }
      # 其他用户没有设置黑名单，应该能看到所有书
      expect(book_ids).to include(clean_book.id, blacklisted_book_record.id)
    end
  end

  # ==================== 无家长管控用户 ====================
  describe "无家长管控用户" do
    let!(:no_pc_user) { create(:app_user) }
    let!(:no_pc_auth_params) { { uuid: no_pc_user.uuid } }

    before do
      parental_control.destroy
    end

    it "无家长管控用户可以正常看到所有图书" do
      get "/api/books/search", params: no_pc_auth_params.merge(keyword: "书")

      expect(response).to have_http_status(200)
      books = json_response[:response][:data][:books]
      book_ids = books.map { |b| b[:id] }
      expect(book_ids).to include(clean_book.id, blacklisted_book_record.id)
    end
  end
end
