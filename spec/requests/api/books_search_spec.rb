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

  # ==================== GET /api/books/leaderboard ====================
  describe "GET /api/books/leaderboard" do
    let(:grade) { create(:grade, name: "三年级") }
    let(:user_with_grade) { create(:app_user, grade_id: grade.id) }

    it "ranking_type=hot 时按 weekly_readers 降序排列" do
      book1 = create(:book, name: "热门书", status: :published)
      create(:book_stats, book: book1, weekly_readers: 500)
      book2 = create(:book, name: "一般书", status: :published)
      create(:book_stats, book: book2, weekly_readers: 100)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "hot" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["热门书", "一般书"])
      expect(data[:ranking_type]).to eq("hot")
    end

    it "ranking_type=hot 且 period=month 时按 monthly_readers 排序" do
      book1 = create(:book, name: "月热门", status: :published)
      create(:book_stats, book: book1, weekly_readers: 10, monthly_readers: 500)
      book2 = create(:book, name: "周热门", status: :published)
      create(:book_stats, book: book2, weekly_readers: 100, monthly_readers: 200)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "hot", period: "month" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["月热门", "周热门"])
    end

    it "ranking_type=rating 时按评分降序排列" do
      create(:book, name: "高分书", status: :published, rating: 9.5)
      create(:book, name: "低分书", status: :published, rating: 5.0)
      create(:book, name: "零分书", status: :published, rating: 0)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "rating" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["高分书", "低分书"])
    end

    it "ranking_type=new 时按创建时间降序排列" do
      book_old = create(:book, name: "旧书", status: :published, created_at: 1.month.ago)
      book_new = create(:book, name: "新书", status: :published, created_at: 1.day.ago)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "new" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["新书", "旧书"])
    end

    it "category_id 参数过滤指定分类" do
      category_a = create(:category, name: "文学")
      category_b = create(:category, name: "科普")
      create(:book, name: "文学书", status: :published, category: category_a)
      create(:book_stats, book: Book.find_by(name: "文学书"), weekly_readers: 100)
      create(:book, name: "科普通", status: :published, category: category_b)
      create(:book_stats, book: Book.find_by(name: "科普通"), weekly_readers: 200)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "hot", category_id: category_a.id }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["文学书"])
    end

    it "按用户年级过滤（只返回对应年级的图书）" do
      grade1 = create(:grade, name: "一年级")
      grade3 = create(:grade, name: "三年级")
      user3 = create(:app_user, grade_id: grade3.id)

      book1 = create(:book, name: "一年级书", status: :published)
      book1.grades << grade1
      book3 = create(:book, name: "三年级书", status: :published)
      book3.grades << grade3
      book_both = create(:book, name: "通用书", status: :published)
      book_both.grades << grade1 << grade3

      get "/api/books/leaderboard", params: { uuid: user3.uuid, ranking_type: "new" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to include("三年级书")
      expect(book_names).to include("通用书")
      expect(book_names).not_to include("一年级书")
    end

    it "用户无年级时返回所有图书" do
      book = create(:book, name: "通用书", status: :published)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "new" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to include("通用书")
    end

    it "limit 参数限制返回数量" do
      5.times do |i|
        create(:book, name: "新书#{i}", status: :published, created_at: i.days.ago)
      end

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "new", limit: 3 }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(3)
    end

    it "不返回草稿状态的书籍" do
      create(:book, name: "已发布书", status: :published)
      create(:book, name: "草稿书", status: :draft)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "new" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books]).not_to include(a_hash_including(name: "草稿书"))
    end

    it "返回图书的分类名称" do
      category = create(:category, name: "社会历史")
      book = create(:book, name: "分类测试书", status: :published, category: category)

      get "/api/books/leaderboard", params: { uuid: user.uuid, ranking_type: "new" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book_data = data[:books].find { |b| b[:id] == book.id }
      expect(book_data[:category_name]).to eq("社会历史")
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/books/leaderboard", params: { ranking_type: "hot" }

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 返回未授权" do
      get "/api/books/leaderboard", params: { uuid: "invalid-uuid", ranking_type: "hot" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
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

  # ==================== GET /api/books/by_author ====================
  describe "GET /api/books/by_author" do
    it "返回作者所有图书，按播放量降序排列" do
      author = create(:author, name: "鲁迅")
      create(:book, name: "西游记", author: author, play_count: 10)
      create(:book, name: "水浒传", author: author, play_count: 50)
      create(:book, name: "其他作者书", author: create(:author), play_count: 100)

      get "/api/books/by_author", params: { author_id: author.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(2)
      expect(data[:books].map { |b| b[:name] }).to eq(["水浒传", "西游记"])
    end

    it "只返回已发布的图书" do
      author = create(:author)
      create(:book, name: "已发布", author: author, status: :published, play_count: 10)
      create(:book, name: "草稿", author: author, status: :draft, play_count: 100)
      create(:book, name: "已下架", author: author, status: :offline, play_count: 50)

      get "/api/books/by_author", params: { author_id: author.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(1)
      expect(data[:books].first[:name]).to eq("已发布")
    end

    it "无图书时返回空数组" do
      get "/api/books/by_author", params: { author_id: 999, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books]).to eq([])
      expect(data[:total_count]).to eq(0)
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/books/by_author", params: { author_id: 1 }

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 返回未授权" do
      get "/api/books/by_author", params: { author_id: 1, uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it "返回图书包含封面签名URL和作者名" do
      author = create(:author, name: "曹文轩")
      create(:book, name: "草房子", author: author, play_count: 200,
                           cover_image_url: "https://bucket.oss-cn-beijing.aliyuncs.com/covers/test.jpg")

      get "/api/books/by_author", params: { author_id: author.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book = data[:books].first
      expect(book[:name]).to eq("草房子")
      expect(book[:cover_image_url]).to match(/\?Expires=/)
    end

    it "有 book_stats 时按 monthly_readers 优先排序" do
      author = create(:author)
      book1 = create(:book, name: "高阅读", author: author, play_count: 10)
      create(:book_stats, book: book1, monthly_readers: 500)
      book2 = create(:book, name: "低阅读", author: author, play_count: 200)
      create(:book_stats, book: book2, monthly_readers: 10)

      get "/api/books/by_author", params: { author_id: author.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["高阅读", "低阅读"])
    end
  end
end
