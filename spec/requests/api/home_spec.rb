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
      expect(recommends.first.keys).to match_array([:id, :name, :sn, :color, :status_text])
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

    context "当用户已设置年级时" do
      before do
        user.update_column(:grade_id, grade.id)
      end

      context "正常场景" do
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
          Content.create!(content_group: content_group, content_type: "compilation", compilation: compilation, sn: 0)
          Content.create!(content_group: content_group, content_type: "book", book: book, sn: 1)
        end

        it "返回指定推荐的详细内容" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          content_groups = json_response[:response][:data][:content_groups]
          expect(content_groups).to be_an(Array)
          expect(content_groups.size).to eq(1)
        end

        it "推荐内容包含 content_groups" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          content_groups = json_response[:response][:data][:content_groups]
          expect(content_groups.size).to eq(1)
        end

        it "内容分组包含正确类型和名称" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          content_groups = json_response[:response][:data][:content_groups].first
          expect(content_groups[:group_type]).to eq("one_row_three_columns")
          expect(content_groups[:group_type_name]).to eq("一排3列")
        end

        it "合集内容包含 compilation 信息" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
          compilation_content = contents.find { |c| c[:content_type] == "compilation" }
          expect(compilation_content[:compilation][:name]).to eq("经典文学合集")
          expect(compilation_content[:compilation][:total_count]).to eq(10)
          expect(compilation_content[:compilation][:cover_url]).to include("banner.jpg")
          expect(compilation_content[:compilation][:cover_url]).to include("OSSAccessKeyId")
        end

        it "单本内容包含 book 信息" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
          book_content = contents.find { |c| c[:content_type] == "book" }
          expect(book_content[:book][:name]).to eq("小王子")
          expect(book_content[:book][:cover_url]).to include("book-cover.jpg")
          expect(book_content[:book][:cover_url]).to include("OSSAccessKeyId")
        end

        it "单本内容包含 category_id, category_name, supplier_name, category_subs" do
          supplier = Supplier.create!(name: "人民文学出版社")
          category_sub = CategorySub.create!(name: "文学经典", category: category, sn: 1)
          book.update!(category: category, supplier: supplier)
          book.category_subs << category_sub

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
          book_content = contents.find { |c| c[:content_type] == "book" }
          book_data = book_content[:book]
          expect(book_data[:category_id]).to eq(category.id)
          expect(book_data[:category_name]).to eq("文学")
          expect(book_data[:supplier_name]).to eq("人民文学出版社")
          expect(book_data[:category_subs]).to eq([{ id: category_sub.id, name: "文学经典", sn: 1 }])
        end

        it "免费图书的 is_free 返回 true" do
          book.update!(is_free: true)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
          book_content = contents.find { |c| c[:content_type] == "book" }
          expect(book_content[:book][:is_free]).to be(true)
        end

        it "付费图书的 is_free 返回 false" do
          book.update!(is_free: false)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
          book_content = contents.find { |c| c[:content_type] == "book" }
          expect(book_content[:book][:is_free]).to be(false)
        end

        it "作者展示类型返回 author 信息" do
          author_group = ContentGroup.create!(
            recommend: recommend,
            name: "名家",
            group_type: "author_display",
            sn: 1
          )
          Content.create!(content_group: author_group, content_type: "author_display", author: author, sn: 0)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          content_groups = json_response[:response][:data][:content_groups]
          author_group_data = content_groups.find { |g| g[:group_type] == "author_display" }
          author_content = author_group_data[:contents].first
          expect(author_content[:author][:name]).to eq("安徒生")
          expect(author_content[:author][:head_img]).to include("author.jpg")
          expect(author_content[:author][:head_img]).to include("OSSAccessKeyId")
        end

        it "内容按 sn 排序" do
          Content.create!(content_group: content_group, content_type: "compilation", compilation: compilation, sn: 10)
          Content.create!(content_group: content_group, content_type: "compilation", compilation: compilation, sn: 5)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
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

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          content_groups = json_response[:response][:data][:content_groups]
          sns = content_groups.map { |cg| cg[:sn] || 0 }
          expect(sns).to eq(sns.sort)
        end

        it "返回多个内容分组" do
          second_group = ContentGroup.create!(
            recommend: recommend,
            name: "第二分组",
            group_type: "single_column",
            sn: 1
          )
          Content.create!(content_group: second_group, content_type: "book", book: book, sn: 0)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          content_groups = json_response[:response][:data][:content_groups]
          expect(content_groups.size).to eq(2)
        end
      end

      context "推荐不存在或不匹配" do
        it "推荐 ID 不存在时返回空数组" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: 999999, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          expect(json_response[:response][:data][:content_groups]).to eq([])
        end

        it "推荐属于其他年级时返回空数组" do
          other_grade = create(:grade, name: "三年级")
          other_recommend = Recommend.create!(grade: other_grade, name: "其他年级", status: true)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: other_recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          expect(json_response[:response][:data][:content_groups]).to eq([])
        end

        it "推荐为草稿状态时返回空数组" do
          draft_recommend = Recommend.create!(grade: grade, name: "草稿推荐", status: false)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: draft_recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          expect(json_response[:response][:data][:content_groups]).to eq([])
        end

        it "content_group 的 group_type 为空字符串时不报 500 错误" do
          recommend = Recommend.create!(grade: grade, name: "测试推荐", status: true)
          content_group = ContentGroup.create!(
            recommend: recommend,
            name: "异常分组",
            group_type: "single_column",
            sn: 0
          )
          content_group.update_column(:group_type, "")
          Content.create!(content_group: content_group, content_type: "book", book: book, sn: 0)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          content_groups = json_response[:response][:data][:content_groups]
          expect(content_groups.size).to eq(1)
          expect(content_groups.first).to have_key(:group_type_name)
        end

        it "content 的 content_type 为空字符串时不报 500 错误" do
          recommend = Recommend.create!(grade: grade, name: "测试推荐", status: true)
          content_group = ContentGroup.create!(
            recommend: recommend,
            name: "测试分组",
            group_type: "single_column",
            sn: 0
          )
          content = Content.create!(content_group: content_group, content_type: "book", book: book, sn: 0)
          content.update_column(:content_type, "")

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          contents = json_response[:response][:data][:content_groups].first[:contents]
          expect(contents.size).to eq(1)
          expect(contents.first).to have_key(:content_type_name)
        end
      end

      context "sub_recommend 内容分组" do
        let!(:parent_recommend) { Recommend.create!(grade: grade, name: "父推荐", status: true) }
        let!(:sub_recommend_group) do
          ContentGroup.create!(
            recommend: parent_recommend,
            name: "二级推荐",
            group_type: "sub_recommend",
            sn: 0
          )
        end
        let!(:child_recommend) { Recommend.create!(grade: grade, name: "子推荐", status: true, sn: 1) }
        let!(:child_content_group) do
          ContentGroup.create!(
            recommend: child_recommend,
            name: "子推荐分组",
            group_type: "single_column",
            sn: 0
          )
        end

        before do
          Content.create!(
            content_group: sub_recommend_group,
            content_type: "recommend",
            recommend: child_recommend,
            sn: 1
          )
          Content.create!(
            content_group: child_content_group,
            content_type: "book",
            book: book,
            sn: 0
          )
        end

        it "返回子推荐的基本信息（不递归 content_groups，避免循环引用）" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: parent_recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          content_groups = json_response[:response][:data][:content_groups]
          sub_group = content_groups.find { |g| g[:group_type] == "sub_recommend" }
          expect(sub_group).to be_present

          recommend_content = sub_group[:contents].first
          expect(recommend_content[:content_type]).to eq("recommend")
          expect(recommend_content[:recommend][:id]).to eq(child_recommend.id)
          expect(recommend_content[:recommend][:name]).to eq("子推荐")
          expect(recommend_content[:recommend][:sn]).to eq(1)
          expect(recommend_content[:recommend][:color]).to be_blank
          expect(recommend_content[:recommend]).not_to have_key(:content_groups)
        end

        it "sub_recommend 内容返回 img_url（含 OSS 签名）" do
          Content.find_by(content_group: sub_recommend_group).update_column(:img_url, "https://epub-files.oss-cn-beijing.aliyuncs.com/recommends/sub_icon.png")

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: parent_recommend.id, uuid: user.uuid }

          recommend_content = json_response[:response][:data][:content_groups].find { |g| g[:group_type] == "sub_recommend" }[:contents].first
          expect(recommend_content[:img_url]).to include("sub_icon.png")
          expect(recommend_content[:img_url]).to include("OSSAccessKeyId")
        end

        it "子推荐指向自身时不报 500 错误（循环引用保护）" do
          # 让子推荐的内容指向父推荐，形成循环引用
          Content.first.update!(recommend: parent_recommend)

          get "/api/home/recommends/by_recommend_id", params: { recommend_id: parent_recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
        end
      end

      context "category_sub 二级分类内容分组" do
        let!(:parent_recommend) { Recommend.create!(grade: grade, name: "分类推荐", status: true) }
        let!(:category) { Category.create!(name: "文学") }
        let!(:category_sub) { CategorySub.create!(name: "文学经典", category: category, icon: "https://example.com/icon.png", sn: 1) }
        let!(:category_sub_group) do
          ContentGroup.create!(
            recommend: parent_recommend,
            name: "二级分类",
            group_type: "single_column",
            sn: 0
          )
        end

        before do
          Content.create!(
            content_group: category_sub_group,
            content_type: "category_sub",
            category_sub: category_sub,
            sn: 0
          )
        end

        it "返回二级分类的 category_sub 信息" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: parent_recommend.id, uuid: user.uuid }

          expect(response).to have_http_status(:success)
          expect(json_response[:response][:code]).to eq(0)
          contents = json_response[:response][:data][:content_groups].first[:contents]
          category_sub_content = contents.find { |c| c[:content_type] == "category_sub" }
          expect(category_sub_content).to be_present
          expect(category_sub_content[:category_sub][:id]).to eq(category_sub.id)
          expect(category_sub_content[:category_sub][:name]).to eq("文学经典")
          expect(category_sub_content[:category_sub][:category_id]).to eq(category.id)
          expect(category_sub_content[:category_sub][:sn]).to eq(1)
        end

        it "二级分类的 icon 返回 OSS 签名 URL" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: parent_recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
          category_sub_content = contents.find { |c| c[:content_type] == "category_sub" }
          expect(category_sub_content[:category_sub][:icon]).to include("icon.png")
          expect(category_sub_content[:category_sub][:icon]).to include("OSSAccessKeyId")
        end

        it "二级分类的 name 作为 display_name" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: parent_recommend.id, uuid: user.uuid }

          contents = json_response[:response][:data][:content_groups].first[:contents]
          category_sub_content = contents.find { |c| c[:content_type] == "category_sub" }
          expect(category_sub_content[:name]).to eq("文学经典")
        end
      end

      context "参数校验" do
        it "recommend_id 不是整数时返回参数错误" do
          get "/api/home/recommends/by_recommend_id", params: { recommend_id: "abc", uuid: user.uuid }

          expect(response).to have_http_status(200)
        end
      end
    end

    context "当用户未设置年级时" do
      it "返回空推荐列表" do
        recommend = Recommend.create!(grade: grade, name: "文学", status: true)
        content_group = ContentGroup.create!(
          recommend: recommend,
          name: "推荐图书",
          group_type: "single_column",
          sn: 0
        )
        Content.create!(content_group: content_group, content_type: "book", book: book, sn: 0)

        get "/api/home/recommends/by_recommend_id", params: { recommend_id: recommend.id, uuid: user.uuid }

        expect(response).to have_http_status(:success)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:content_groups]).to eq([])
      end
    end

    context "未登录时" do
      it "返回未授权错误" do
        get "/api/home/recommends/by_recommend_id", params: { recommend_id: 1, uuid: "invalid-uuid" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to be > 0
      end
    end
  end
end
