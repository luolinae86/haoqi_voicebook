# frozen_string_literal: true

require "rails_helper"

RSpec.xdescribe "API Bookshelves", type: :request do
  let(:user) { create(:app_user) }
  let(:headers) { auth_headers(user) }
  let(:book) { create(:book) }
  let(:chapter) { create(:chapter, book: book) }

  # ==================== 获取书架 ====================
  describe "GET /api/bookshelves" do
    context "已登录" do
      before do
        create_list(:bookshelf, 3, app_user: user)
      end

      it "返回用户书架列表" do
        get "/api/bookshelves", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data]).to be_an(Array)
        expect(json_response[:data].size).to eq(3)
      end

      it "支持分页" do
        get "/api/bookshelves", params: { page: 1, per_page: 2 }, headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:data].size).to be <= 2
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/bookshelves"

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 添加图书到书架 ====================
  describe "POST /api/bookshelves" do
    context "已登录" do
      it "添加图书成功" do
        expect do
          post "/api/bookshelves", params: { book_id: book.id }, headers: headers
        end.to change(Bookshelf, :count).by(1)

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "重复添加同一本书不会创建新记录" do
        create(:bookshelf, app_user: user, book: book)

        expect do
          post "/api/bookshelves", params: { book_id: book.id }, headers: headers
        end.not_to change(Bookshelf, :count)
      end

      it "图书不存在时返回错误" do
        post "/api/bookshelves", params: { book_id: 999_999 }, headers: headers

        expect(response).to have_http_status(404).or have_http_status(400)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/bookshelves", params: { book_id: book.id }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 从书架移除 ====================
  describe "DELETE /api/bookshelves/:book_id" do
    context "已登录" do
      let!(:shelf_item) { create(:bookshelf, app_user: user, book: book) }

      it "移除图书成功" do
        expect do
          delete "/api/bookshelves/#{book.id}", headers: headers
        end.to change(Bookshelf, :count).by(-1)

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end

      it "移除不存在的图书返回错误" do
        delete "/api/bookshelves/999999", headers: headers

        expect(response).to have_http_status(404).or have_http_status(400)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        delete "/api/bookshelves/#{book.id}"

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 更新阅读进度 ====================
  describe "PUT /api/bookshelves/:book_id/progress" do
    context "已登录" do
      let!(:shelf_item) { create(:bookshelf, app_user: user, book: book) }

      it "更新阅读进度成功" do
        put "/api/bookshelves/#{book.id}/progress",
            params: { progress: 50.0, chapter_id: chapter.id },
            headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(shelf_item.reload.reading_progress.to_f).to eq(50.0)
      end

      it "进度范围为 0-100" do
        put "/api/bookshelves/#{book.id}/progress",
            params: { progress: 100.0 },
            headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        put "/api/bookshelves/#{book.id}/progress", params: { progress: 50.0 }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 记录阅读 ====================
  describe "POST /api/bookshelves/:book_id/reading_records" do
    context "已登录" do
      let!(:shelf_item) { create(:bookshelf, app_user: user, book: book) }

      it "记录阅读成功" do
        expect do
          post "/api/bookshelves/#{book.id}/reading_records",
               params: { chapter_id: chapter.id, words_read: 500, duration_minutes: 15 },
               headers: headers
        end.to change(ReadingRecord, :count).by(1)

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "更新用户阅读统计" do
        post "/api/bookshelves/#{book.id}/reading_records",
             params: { words_read: 1000, duration_minutes: 30 },
             headers: headers

        expect(response).to have_http_status(200).or have_http_status(201)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/bookshelves/#{book.id}/reading_records",
             params: { words_read: 500, duration_minutes: 10 }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 书签列表 ====================
  describe "GET /api/bookmarks" do
    context "已登录" do
      before do
        create_list(:bookmark, 3, app_user: user)
      end

      it "返回用户书签列表" do
        get "/api/bookmarks", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data]).to be_an(Array)
        expect(json_response[:data].size).to eq(3)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/bookmarks"

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 添加书签 ====================
  describe "POST /api/bookmarks" do
    context "已登录" do
      it "添加书签成功" do
        expect do
          post "/api/bookmarks",
               params: { book_id: book.id, chapter_id: chapter.id, position: 120 },
               headers: headers
        end.to change(Bookmark, :count).by(1)

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "缺少 book_id 返回错误" do
        post "/api/bookmarks", params: { position: 100 }, headers: headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/bookmarks", params: { book_id: book.id }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 删除书签 ====================
  describe "DELETE /api/bookmarks/:id" do
    context "已登录" do
      let!(:bookmark) { create(:bookmark, app_user: user, book: book) }

      it "删除书签成功" do
        expect do
          delete "/api/bookmarks/#{bookmark.id}", headers: headers
        end.to change(Bookmark, :count).by(-1)

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end

      it "删除不存在的书签返回错误" do
        delete "/api/bookmarks/999999", headers: headers

        expect(response).to have_http_status(404)
      end

      it "不能删除其他用户的书签" do
        other_user = create(:app_user)
        other_bookmark = create(:bookmark, app_user: other_user)

        delete "/api/bookmarks/#{other_bookmark.id}", headers: headers

        expect(response).to have_http_status(404).or have_http_status(403)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        bookmark = create(:bookmark, app_user: user)
        delete "/api/bookmarks/#{bookmark.id}"

        expect(response).to have_http_status(401)
      end
    end
  end
end
