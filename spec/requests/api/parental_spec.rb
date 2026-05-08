# frozen_string_literal: true

require "rails_helper"

RSpec.xdescribe "API Parental Control", type: :request do
  let(:user) { create(:app_user) }
  let(:headers) { auth_headers(user) }

  # ==================== 设置家长密码 ====================
  describe "POST /api/parental/setup" do
    context "已登录" do
      it "首次设置家长密码成功" do
        post "/api/parental/setup", params: { password: "1234" }, headers: headers

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "创建家长控制记录" do
        expect do
          post "/api/parental/setup", params: { password: "1234" }, headers: headers
        end.to change(ParentalControl, :count).by(1)
      end

      it "已设置过不能重复创建" do
        create(:parental_control, app_user: user)

        post "/api/parental/setup", params: { password: "5678" }, headers: headers

        expect(json_response[:code]).not_to eq(0)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/parental/setup", params: { password: "1234" }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 验证家长密码 ====================
  describe "POST /api/parental/verify" do
    let!(:parental_control) { create(:parental_control, app_user: user, password: "123456") }

    context "已登录" do
      it "密码正确验证通过" do
        post "/api/parental/verify", params: { password: "123456" }, headers: headers

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "密码错误验证失败" do
        post "/api/parental/verify", params: { password: "wrong" }, headers: headers

        expect(json_response[:code]).not_to eq(0)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/parental/verify", params: { password: "123456" }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 获取设置 ====================
  describe "GET /api/parental/settings" do
    context "已登录" do
      let!(:parental_control) { create(:parental_control, app_user: user, time_limit_minutes: 60) }

      it "返回家长控制设置" do
        get "/api/parental/settings", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data]).to be_present
        expect(json_response[:data][:time_limit_minutes]).to eq(60)
      end
    end

    context "未设置家长控制" do
      it "返回空或提示设置" do
        get "/api/parental/settings", headers: headers

        expect(response).to have_http_status(200).or have_http_status(404)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/parental/settings"

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 设置时间限制 ====================
  describe "PUT /api/parental/time_limit" do
    let!(:parental_control) { create(:parental_control, app_user: user) }

    context "已登录" do
      it "设置时间限制成功" do
        put "/api/parental/time_limit",
            params: { time_limit_minutes: 30 },
            headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(parental_control.reload.time_limit_minutes).to eq(30)
      end

      it "取消时间限制" do
        put "/api/parental/time_limit",
            params: { time_limit_minutes: nil },
            headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(parental_control.reload.time_limit_minutes).to be_nil
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        put "/api/parental/time_limit", params: { time_limit_minutes: 30 }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 设置家长手机号 ====================
  describe "PUT /api/parental/phone" do
    let!(:parental_control) { create(:parental_control, app_user: user) }
    let!(:sms_verification) do
      create(:sms_verification, phone: "13900001111", code: "8888", expires_at: 5.minutes.from_now)
    end

    context "已登录" do
      it "设置家长手机号成功" do
        put "/api/parental/phone",
            params: { phone: "13900001111", code: "8888" },
            headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end

      it "验证码错误设置失败" do
        put "/api/parental/phone",
            params: { phone: "13900001111", code: "0000" },
            headers: headers

        expect(json_response[:code]).not_to eq(0)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        put "/api/parental/phone", params: { phone: "13900001111", code: "8888" }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 黑名单列表 ====================
  describe "GET /api/parental/blacklist" do
    let!(:parental_control) { create(:parental_control, app_user: user) }

    context "已登录" do
      let!(:blacklisted) { create(:blacklisted_book, parental_control: parental_control) }

      it "返回黑名单图书列表" do
        get "/api/parental/blacklist", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data]).to be_an(Array)
        expect(json_response[:data].size).to eq(1)
      end
    end

    context "黑名单为空" do
      it "返回空列表" do
        get "/api/parental/blacklist", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data]).to be_empty
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/parental/blacklist"

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 添加到黑名单 ====================
  describe "POST /api/parental/blacklist" do
    let!(:parental_control) { create(:parental_control, app_user: user) }
    let(:book) { create(:book) }

    context "已登录" do
      it "添加图书到黑名单成功" do
        expect do
          post "/api/parental/blacklist", params: { book_id: book.id }, headers: headers
        end.to change(BlacklistedBook, :count).by(1)

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "重复添加不会创建新记录" do
        create(:blacklisted_book, parental_control: parental_control, book: book)

        expect do
          post "/api/parental/blacklist", params: { book_id: book.id }, headers: headers
        end.not_to change(BlacklistedBook, :count)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/parental/blacklist", params: { book_id: book.id }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 从黑名单移除 ====================
  describe "DELETE /api/parental/blacklist/:book_id" do
    let!(:parental_control) { create(:parental_control, app_user: user) }
    let(:book) { create(:book) }
    let!(:blacklisted) { create(:blacklisted_book, parental_control: parental_control, book: book) }

    context "已登录" do
      it "从黑名单移除成功" do
        expect do
          delete "/api/parental/blacklist/#{book.id}", headers: headers
        end.to change(BlacklistedBook, :count).by(-1)

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end

      it "移除不存在的图书返回错误" do
        delete "/api/parental/blacklist/999999", headers: headers

        expect(response).to have_http_status(404).or have_http_status(400)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        delete "/api/parental/blacklist/#{book.id}"

        expect(response).to have_http_status(401)
      end
    end
  end
end
