# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Home", type: :request do
  let(:user) { create(:app_user) }
  let(:grade) { create(:grade, name: "二年级") }
  let(:aliyun_oss_service) { instance_double(AliyunOssService) }

  before do
    allow(AliyunOssService).to receive(:new).and_return(aliyun_oss_service)
    allow(aliyun_oss_service).to receive(:generate_signed_url) do |object_key, **|
      "https://epub-files.oss-cn-beijing.aliyuncs.com/#{object_key}?OSSAccessKeyId=xxx&Expires=1234567890&Signature=yyy"
    end
  end

  # ==================== 获取推荐列表（仅 recommends 层级） ====================
  describe "GET /api/home/recommends" do
    let!(:category) { Category.create!(name: "文学") }
    let!(:book) do
      Book.create!(
        name: "小王子",
        cover_image_url: "https://example.com/book-cover.jpg",
        category: category
      )
    end

    before do
      user.update_column(:grade_id, grade.id)
    end

    it "返回推荐列表（仅 recommends 层级）" do
      Recommend.create!(grade: grade, name: "文学", status: true, sn: 1)
      Recommend.create!(grade: grade, name: "科学", status: true, sn: 2)

      get "/api/home/recommends", params: { uuid: user.uuid }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      recommends = json_response[:response][:data][:recommends]
      expect(recommends.size).to eq(2)
      expect(recommends.first.keys).to match_array([:id, :name, :sn, :status_text])
    end

    it "返回的推荐不包含 content_groups" do
      recommend = Recommend.create!(grade: grade, name: "文学", status: true, sn: 1)
      ContentGroup.create!(
        recommend: recommend,
        name: "推荐图书",
        group_type: "one_row_three_columns",
        sn: 0
      )

      get "/api/home/recommends", params: { uuid: user.uuid }

      recommends = json_response[:response][:data][:recommends]
      recommends.each do |r|
        expect(r).not_to have_key(:content_groups)
      end
    end

    it "不返回草稿状态的推荐" do
      Recommend.create!(grade: grade, name: "已发布", status: true, sn: 1)
      Recommend.create!(grade: grade, name: "草稿", status: false, sn: 2)

      get "/api/home/recommends", params: { uuid: user.uuid }

      recommends = json_response[:response][:data][:recommends]
      expect(recommends.map { |r| r[:name] }).to eq(["已发布"])
    end

    it "用户未设置年级时返回空数组" do
      user.update_column(:grade_id, nil)

      get "/api/home/recommends", params: { uuid: user.uuid }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:data][:recommends]).to eq([])
    end

    it "未登录时返回未授权错误" do
      get "/api/home/recommends", params: { uuid: "invalid-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end
  end

  # ==================== 获取首页推荐 ====================
  describe "GET /api/home" do
    context "当用户已设置年级时" do
      let!(:category) { Category.create!(name: "文学") }
      let!(:compilation) do
        Compilation.create!(
          name: "经典文学合集",
          editor_recommendation: "经典推荐",
          total_count: 10,
          banner_image_url: "https://example.com/banner.jpg"
        )
      end
      let!(:book) do
        Book.create!(
          name: "小王子",
          cover_image_url: "https://example.com/book-cover.jpg",
          category: category
        )
      end
      let!(:author) { Author.create!(name: "安徒生", head_img: "https://example.com/author.jpg") }
      let!(:recommend) { Recommend.create!(grade: grade, name: "文学", status: true) }
      let!(:content_group) do
        ContentGroup.create!(
          recommend: recommend,
          name: "推荐图书",
          group_type: "one_row_three_columns",
          sn: 0
        )
      end

      before do
        user.update_column(:grade_id, grade.id)

        Content.create!(content_group: content_group, content_type: "compilation", compilation: compilation, sn: 0)
        Content.create!(content_group: content_group, content_type: "book", book: book, sn: 1)
      end

      it "返回首页推荐内容" do
        get "/api/home", params: { uuid: user.uuid }

        expect(response).to have_http_status(:success)
        expect(json_response[:response][:code]).to eq(0)
        recommends = json_response[:response][:data][:recommends]
        expect(recommends).to be_an(Array)
        expect(recommends.size).to eq(1)
        expect(recommends.first[:name]).to eq("文学")
      end

      it "推荐内容包含 content_groups" do
        get "/api/home", params: { uuid: user.uuid }

        recommends = json_response[:response][:data][:recommends]
        content_groups = recommends.first[:content_groups]
        expect(content_groups.size).to eq(1)
      end

      it "内容分组包含正确类型和名称" do
        get "/api/home", params: { uuid: user.uuid }

        content_groups = json_response[:response][:data][:recommends].first[:content_groups].first
        expect(content_groups[:group_type]).to eq("one_row_three_columns")
        expect(content_groups[:group_type_name]).to eq("一排3列")
      end

      it "合集内容包含 compilation 信息" do
        get "/api/home", params: { uuid: user.uuid }

        contents = json_response[:response][:data][:recommends].first[:content_groups].first[:contents]
        compilation_content = contents.find { |c| c[:content_type] == "compilation" }
        expect(compilation_content[:compilation][:name]).to eq("经典文学合集")
        expect(compilation_content[:compilation][:total_count]).to eq(10)
        expect(compilation_content[:compilation][:cover_url]).to include("banner.jpg")
        expect(compilation_content[:compilation][:cover_url]).to include("OSSAccessKeyId")
      end

      it "单本内容包含 book 信息" do
        get "/api/home", params: { uuid: user.uuid }

        contents = json_response[:response][:data][:recommends].first[:content_groups].first[:contents]
        book_content = contents.find { |c| c[:content_type] == "book" }
        expect(book_content[:book][:name]).to eq("小王子")
        expect(book_content[:book][:cover_url]).to include("book-cover.jpg")
        expect(book_content[:book][:cover_url]).to include("OSSAccessKeyId")
      end

      it "不返回草稿状态的推荐内容" do
        draft_recommend = Recommend.create!(grade: grade, name: "草稿推荐", status: false)
        draft_group = ContentGroup.create!(
          recommend: draft_recommend,
          name: "草稿分组",
          group_type: "single_column",
          sn: 0
        )
        Content.create!(content_group: draft_group, content_type: "book", book: book, sn: 0)

        get "/api/home", params: { uuid: user.uuid }

        recommends = json_response[:response][:data][:recommends]
        expect(recommends.any? { |r| r[:name] == "草稿推荐" }).to be false
      end

      it "返回多个推荐内容" do
        book_recommend = Recommend.create!(grade: grade, name: "图书", status: true, sn: 1)
        book_group = ContentGroup.create!(
          recommend: book_recommend,
          name: "热门图书",
          group_type: "one_row_two_columns",
          sn: 0
        )
        Content.create!(content_group: book_group, content_type: "book", book: book, sn: 0)

        get "/api/home", params: { uuid: user.uuid }

        recommends = json_response[:response][:data][:recommends]
        expect(recommends.size).to eq(2)
        expect(recommends.map { |r| r[:name] }).to eq(["文学", "图书"])
      end

      it "作者展示类型返回 author 信息" do
        author_group = ContentGroup.create!(
          recommend: recommend,
          name: "名家",
          group_type: "author_display",
          sn: 1
        )
        Content.create!(content_group: author_group, content_type: "author_display", author: author, sn: 0)

        get "/api/home", params: { uuid: user.uuid }

        content_groups = json_response[:response][:data][:recommends].first[:content_groups]
        author_group_data = content_groups.find { |g| g[:group_type] == "author_display" }
        author_content = author_group_data[:contents].first
        expect(author_content[:author][:name]).to eq("安徒生")
        expect(author_content[:author][:head_img]).to include("author.jpg")
        expect(author_content[:author][:head_img]).to include("OSSAccessKeyId")
      end

      it "只返回当前用户年级的推荐内容" do
        other_grade = create(:grade, name: "三年级")
        other_recommend = Recommend.create!(grade: other_grade, name: "其他年级", status: true)
        other_group = ContentGroup.create!(
          recommend: other_recommend,
          name: "其他分组",
          group_type: "single_column",
          sn: 0
        )
        Content.create!(content_group: other_group, content_type: "book", book: book, sn: 0)

        get "/api/home", params: { uuid: user.uuid }

        recommends = json_response[:response][:data][:recommends]
        expect(recommends.any? { |r| r[:name] == "其他年级" }).to be false
      end

      it "该年级无推荐时返回空数组" do
        user.update_column(:grade_id, nil)
        other_grade = create(:grade, name: "四年级")
        user.update_column(:grade_id, other_grade.id)

        get "/api/home", params: { uuid: user.uuid }

        recommends = json_response[:response][:data][:recommends]
        expect(recommends).to eq([])
      end

      it "内容按 sn 排序" do
        Content.create!(content_group: content_group, content_type: "compilation", compilation: compilation, sn: 10)
        Content.create!(content_group: content_group, content_type: "compilation", compilation: compilation, sn: 5)

        get "/api/home", params: { uuid: user.uuid }

        contents = json_response[:response][:data][:recommends].first[:content_groups].first[:contents]
        sns = contents.map { |c| c[:sn] }
        expect(sns).to eq(sns.sort)
      end

      it "内容分组按 sn 排序" do
        second_group = ContentGroup.create!(
          recommend: recommend,
          name: "第二分组",
          group_type: "single_column",
          sn: 10
        )
        Content.create!(content_group: second_group, content_type: "book", book: book, sn: 0)

        first_group = ContentGroup.create!(
          recommend: recommend,
          name: "第一分组",
          group_type: "single_column",
          sn: 5
        )
        Content.create!(content_group: first_group, content_type: "book", book: book, sn: 0)

        get "/api/home", params: { uuid: user.uuid }

        content_groups = json_response[:response][:data][:recommends].first[:content_groups]
        sns = content_groups.map { |cg| cg[:sn] || 0 }
        expect(sns).to eq(sns.sort)
      end
    end

    context "当用户未设置年级时" do
      it "返回空推荐列表" do
        get "/api/home", params: { uuid: user.uuid }

        expect(response).to have_http_status(:success)
        expect(json_response[:response][:code]).to eq(0)
        recommends = json_response[:response][:data][:recommends]
        expect(recommends).to eq([])
      end
    end

    context "未登录时" do
      it "返回未授权错误" do
        get "/api/home", params: { uuid: "invalid-uuid" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to be > 0
      end
    end
  end
end
