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

    # -- 搜索所有类型资源 --
    it "搜索结果包含所有类型的资源（ebook/audio/video）" do
      author = create(:author)
      create(:book, name: "有声西游记", author: author, content_type: :audio, play_count: 100)
      create(:book, name: "视频西游记", author: author, content_type: :video, play_count: 200)
      create(:book, name: "图书西游记", author: author, content_type: :ebook, play_count: 300)

      get "/api/books/search", params: { keyword: "西游记", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(3)
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to include("有声西游记", "视频西游记", "图书西游记")
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

    # -- 所有状态均可被搜索 --
    it "搜索草稿和已发布状态的书籍" do
      author = create(:author)
      create(:book, name: "已发布书", author: author, status: :published)
      create(:book, name: "草稿书", author: author, status: :draft)
      create(:book, name: "已下架书", author: author, status: :offline)

      get "/api/books/search", params: { keyword: "书", uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(3)
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to include("已发布书", "草稿书", "已下架书")
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
    let(:ebook_category) { create(:category, name: "图书") }
    let(:grade) { create(:grade, name: "三年级") }
    let(:user_with_grade) { create(:app_user, grade_id: grade.id) }

    it "ranking_type=hot 时按 weekly_readers 降序排列" do
      book1 = create(:book, name: "热门书", status: :published, category: ebook_category)
      create(:book_stats, book: book1, weekly_readers: 500)
      book2 = create(:book, name: "一般书", status: :published, category: ebook_category)
      create(:book_stats, book: book2, weekly_readers: 100)

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "hot" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["热门书", "一般书"])
      expect(data[:ranking_type]).to eq("hot")
    end

    it "ranking_type=rating 时按评分降序排列" do
      create(:book, name: "高分书", status: :published, category: ebook_category, rating: 9.5)
      create(:book, name: "低分书", status: :published, category: ebook_category, rating: 5.0)
      create(:book, name: "零分书", status: :published, category: ebook_category, rating: 0)

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "rating" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["高分书", "低分书"])
    end

    it "ranking_type=new 时按创建时间降序排列" do
      book_old = create(:book, name: "旧书", status: :published, category: ebook_category, created_at: 1.month.ago)
      book_new = create(:book, name: "新书", status: :published, category: ebook_category, created_at: 1.day.ago)

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "new" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].map { |b| b[:name] }).to eq(["新书", "旧书"])
    end

    it "ranking_type=award 时只返回关联了「大奖版」category_sub 的图书" do
      award_sub = create(:category_sub, name: "大奖版", category: ebook_category)
      classic_sub = create(:category_sub, name: "名著榜", category: ebook_category)

      award_book = create(:book, name: "大奖书", status: :published, category: ebook_category)
      award_book.category_subs << award_sub
      classic_book = create(:book, name: "名著书", status: :published, category: ebook_category)
      classic_book.category_subs << classic_sub
      normal_book = create(:book, name: "普通书", status: :published, category: ebook_category)

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "award" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to include("大奖书")
      expect(book_names).not_to include("名著书", "普通书")
    end

    it "ranking_type=classic 时只返回关联了「名著榜」category_sub 的图书" do
      award_sub = create(:category_sub, name: "大奖版", category: ebook_category)
      classic_sub = create(:category_sub, name: "名著榜", category: ebook_category)

      award_book = create(:book, name: "大奖书", status: :published, category: ebook_category)
      award_book.category_subs << award_sub
      classic_book = create(:book, name: "名著书", status: :published, category: ebook_category)
      classic_book.category_subs << classic_sub
      normal_book = create(:book, name: "普通书", status: :published, category: ebook_category)

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "classic" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to include("名著书")
      expect(book_names).not_to include("大奖书", "普通书")
    end

    it "category_id 参数过滤指定分类" do
      audio_category = create(:category, name: "有声")
      create(:book, name: "图书类书", status: :published, category: ebook_category)
      create(:book, name: "有声类书", status: :published, category: audio_category)

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "hot" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to include("图书类书")
      expect(book_names).not_to include("有声类书")
    end

    it "按用户年级过滤（只返回对应年级的图书）" do
      grade1 = create(:grade, name: "一年级")
      grade3 = create(:grade, name: "三年级")
      user3 = create(:app_user, grade_id: grade3.id)

      book1 = create(:book, name: "一年级书", status: :published, category: ebook_category)
      book1.grades << grade1
      book3 = create(:book, name: "三年级书", status: :published, category: ebook_category)
      book3.grades << grade3
      book_both = create(:book, name: "通用书", status: :published, category: ebook_category)
      book_both.grades << grade1 << grade3

      get "/api/books/hot_search", params: { uuid: user3.uuid, category_id: ebook_category.id, ranking_type: "hot" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book_names = data[:books].map { |b| b[:name] }
      expect(book_names).to include("三年级书")
      expect(book_names).to include("通用书")
      expect(book_names).not_to include("一年级书")
    end

    it "limit 参数限制返回数量" do
      5.times do |i|
        create(:book, name: "新书#{i}", status: :published, category: ebook_category, created_at: i.days.ago)
      end

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "new", limit: 3 }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(3)
    end

    it "不返回草稿状态的书籍" do
      create(:book, name: "已发布书", status: :published, category: ebook_category)
      create(:book, name: "草稿书", status: :draft, category: ebook_category)

      get "/api/books/hot_search", params: { uuid: user.uuid, category_id: ebook_category.id, ranking_type: "hot" }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books]).not_to include(a_hash_including(name: "草稿书"))
    end

    it "未提供 category_id 参数时返回参数错误" do
      get "/api/books/hot_search", params: { uuid: user.uuid, ranking_type: "hot" }

      expect(response).to have_http_status(200)
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/books/hot_search", params: { category_id: 1, ranking_type: "hot" }

      expect(response).to have_http_status(200)
    end

    it "无效 uuid 返回未授权" do
      get "/api/books/hot_search", params: { uuid: "invalid-uuid", category_id: 1, ranking_type: "hot" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
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

    it "返回图书包含分类名、简介和出版社名" do
      author = create(:author, name: "曹文轩")
      category = create(:category, name: "儿童文学")
      supplier = create(:supplier, name: "人民文学出版社")
      create(:book, name: "草房子", author: author, play_count: 200,
                           category: category, supplier: supplier,
                           content_description: "这是一本好书")

      get "/api/books/by_author", params: { author_id: author.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      book = data[:books].first
      expect(book[:category_name]).to eq("儿童文学")
      expect(book[:content_description]).to eq("这是一本好书")
      expect(book[:supplier_name]).to eq("人民文学出版社")
    end

    it "category_id 参数过滤指定分类" do
      author = create(:author)
      cat_a = create(:category, name: "文学")
      cat_b = create(:category, name: "科普")
      create(:book, name: "文学书", author: author, category: cat_a, play_count: 10)
      create(:book, name: "科普书", author: author, category: cat_b, play_count: 50)

      get "/api/books/by_author", params: { author_id: author.id, category_id: cat_a.id, uuid: user.uuid }

      expect(response).to have_http_status(200)
      data = json_response[:response][:data]
      expect(data[:books].size).to eq(1)
      expect(data[:books].first[:name]).to eq("文学书")
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
