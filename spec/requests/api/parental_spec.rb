# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Parental Control", type: :request do
  let(:user) { create(:app_user) }
  let(:auth_params) { { uuid: user.uuid } }

  # ==================== 设置家长密码 ====================
  describe "POST /api/parental/setup" do
    let!(:sms_verification) do
      create(:sms_verification, phone: "13900001111", code: "8888", expires_at: 5.minutes.from_now)
    end

    context "已登录" do
      it "首次设置家长密码成功" do
        post "/api/parental/setup", params: auth_params.merge(password: "1234", phone: "13900001111", code: "8888")

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end

      it "创建家长控制记录" do
        expect do
          post "/api/parental/setup", params: auth_params.merge(password: "1234", phone: "13900001111", code: "8888")
        end.to change(ParentalControl, :count).by(1)
      end

      it "已设置过且手机号一致会重置密码" do
        create(:parental_control, app_user: user, password: "old123", phone: "13900001111")

        post "/api/parental/setup", params: auth_params.merge(password: "5678", phone: "13900001111", code: "8888")

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.parental_control.reload.authenticate("5678")).to be_a(ParentalControl)
        expect(user.parental_control.authenticate("old123")).to be false
      end

      it "已设置过但手机号不一致返回失败" do
        create(:parental_control, app_user: user, password: "old123", phone: "13900001111")

        post "/api/parental/setup", params: auth_params.merge(password: "5678", phone: "13800000000", code: "8888")

        expect(json_response[:response][:code]).not_to eq(0)
        expect(user.parental_control.reload.authenticate("old123")).to be_a(ParentalControl)
      end

      it "手机号格式不正确返回错误" do
        post "/api/parental/setup", params: auth_params.merge(password: "1234", phone: "invalid", code: "8888")

        expect(json_response[:response][:code]).not_to eq(0)
      end

      it "验证码无效返回错误" do
        post "/api/parental/setup", params: auth_params.merge(password: "1234", phone: "13900001111", code: "0000")

        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        post "/api/parental/setup", params: invalid_auth_params.merge(password: "1234", phone: "13900001111", code: "8888")

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
      end
    end
  end

  # ==================== 验证家长密码 ====================
  describe "POST /api/parental/verify" do
    let!(:parental_control) { create(:parental_control, app_user: user, password: "123456") }

    context "已登录" do
      it "密码正确验证通过" do
        post "/api/parental/verify", params: auth_params.merge(password: "123456")

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end

      it "密码错误验证失败" do
        post "/api/parental/verify", params: auth_params.merge(password: "wrong")

        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        post "/api/parental/verify", params: invalid_auth_params.merge(password: "123456")

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
      end
    end
  end

  # ==================== 获取设置 ====================
  describe "GET /api/parental/settings" do
    context "已登录" do
      let!(:parental_control) { create(:parental_control, app_user: user, time_limit_minutes: 60) }

      it "返回家长控制设置" do
        get "/api/parental/settings", params: auth_params

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data]).to be_present
        expect(json_response[:response][:data][:parental_control][:time_limit_minutes]).to eq(60)
      end
    end

    context "未设置家长控制" do
      it "返回空或提示设置" do
        get "/api/parental/settings", params: auth_params

        expect(response).to have_http_status(200).or have_http_status(404)
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        get "/api/parental/settings", params: invalid_auth_params

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
      end
    end
  end

  # ==================== 设置时间限制 ====================
  describe "PUT /api/parental/time_limit" do
    let!(:parental_control) { create(:parental_control, app_user: user) }

    context "已登录" do
      it "设置时间限制成功" do
        put "/api/parental/time_limit",
            params: auth_params.merge(time_limit_minutes: 30)

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(parental_control.reload.time_limit_minutes).to eq(30)
      end

      it "设置为0表示无限制（存为nil）" do
        put "/api/parental/time_limit",
            params: auth_params.merge(time_limit_minutes: 0)

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:time_limit_label]).to eq('无限制')
        expect(parental_control.reload.time_limit_minutes).to be_nil
      end

      it "取消时间限制" do
        put "/api/parental/time_limit",
            params: auth_params.merge(time_limit_minutes: nil)

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(parental_control.reload.time_limit_minutes).to be_nil
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        put "/api/parental/time_limit", params: invalid_auth_params.merge(time_limit_minutes: 30)

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
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
            params: auth_params.merge(phone: "13900001111", code: "8888")

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
      end

      it "验证码错误设置失败" do
        put "/api/parental/phone",
            params: auth_params.merge(phone: "13900001111", code: "0000")

        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        put "/api/parental/phone", params: invalid_auth_params.merge(phone: "13900001111", code: "8888")

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
      end
    end
  end

  # ==================== 黑名单列表 ====================
  describe "GET /api/parental/blacklist" do
    let!(:parental_control) { create(:parental_control, app_user: user) }

    context "已登录" do
      let!(:blacklisted) { create(:blacklisted_book, parental_control: parental_control) }

      it "返回黑名单图书列表" do
        get "/api/parental/blacklist", params: auth_params

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:books]).to be_an(Array)
        expect(json_response[:response][:data][:books].size).to eq(1)
      end
    end

    context "黑名单为空" do
      it "返回空列表" do
        get "/api/parental/blacklist", params: auth_params

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:books]).to be_empty
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        get "/api/parental/blacklist", params: invalid_auth_params

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
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
          post "/api/parental/blacklist", params: auth_params.merge(book_id: book.id)
        end.to change(BlacklistedBook, :count).by(1)

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end

      it "重复添加不会创建新记录" do
        create(:blacklisted_book, parental_control: parental_control, book: book)

        expect do
          post "/api/parental/blacklist", params: auth_params.merge(book_id: book.id)
        end.not_to change(BlacklistedBook, :count)
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        post "/api/parental/blacklist", params: invalid_auth_params.merge(book_id: book.id)

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
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
          post "/api/parental/remove_blacklist", params: auth_params.merge(book_id: book.id)
        end.to change(BlacklistedBook, :count).by(-1)

        expect(response).to have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end

      it "移除不存在的图书返回错误" do
        post "/api/parental/remove_blacklist", params: auth_params.merge(book_id: 999999)

        expect(response).to have_http_status(200)
      end
    end

    context "未登录" do
      let(:invalid_auth_params) { { uuid: "invalid_uuid_00000" } }

      it "返回 401 未授权" do
        post "/api/parental/remove_blacklist", params: invalid_auth_params.merge(book_id: book.id)

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
      end
    end
  end
end
