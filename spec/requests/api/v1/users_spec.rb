# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Users", type: :request do
  let(:user) { create(:user, phone: "13800138000", password: "password123") }
  let(:headers) { auth_headers(user) }

  # ==================== 发送验证码 ====================
  describe "POST /api/users/send_code" do
    context "手机号格式正确" do
      it "发送验证码成功" do
        post "/api/users/send_code", params: { phone: "13800138001" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "创建短信验证记录" do
        expect {
          post "/api/users/send_code", params: { phone: "13800138001" }
        }.to change(SmsVerification, :count).by(1)
      end
    end

    context "手机号格式不正确" do
      it "返回参数错误" do
        post "/api/users/send_code", params: { phone: "123" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("手机号格式不正确")
        expect(json_response[:response][:data]).to be_nil
      end
    end

    context "缺少手机号参数" do
      it "返回参数错误" do
        post "/api/users/send_code", params: {}

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  # ==================== 验证码登录 ====================
  describe "POST /api/users/login_by_code" do
    let!(:sms_verification) do
      create(:sms_verification, phone: "13800138000", code: "1234", expires_at: 5.minutes.from_now)
    end

    context "验证码正确" do
      it "登录成功并返回 token" do
        post "/api/users/login_by_code", params: { phone: "13800138000", code: "1234" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data][:token]).to be_present
        expect(json_response[:data][:user]).to be_present
      end
    end

    context "验证码错误" do
      it "返回错误信息" do
        post "/api/users/login_by_code", params: { phone: "13800138000", code: "9999" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("验证码无效或已过期")
      end
    end

    context "手机号未注册" do
      it "自动创建新用户并返回 token" do
        new_phone = "13900139000"
        create(:sms_verification, phone: new_phone, code: "5678", expires_at: 5.minutes.from_now)

        expect {
          post "/api/users/login_by_code", params: { phone: new_phone, code: "5678" }
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data][:token]).to be_present
      end
    end

    context "验证码已过期" do
      it "返回错误信息" do
        expired_sms = create(:sms_verification, :expired, phone: "13700137000", code: "4321")

        post "/api/users/login_by_code", params: { phone: "13700137000", code: "4321" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("验证码无效或已过期")
      end
    end
  end

  # ==================== 密码登录 ====================
  describe "POST /api/users/login_by_password" do
    context "密码正确" do
      it "登录成功并返回 token" do
        post "/api/users/login_by_password", params: { phone: user.phone, password: "password123" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data][:token]).to be_present
        expect(json_response[:data][:user]).to be_present
        expect(json_response[:data][:user][:phone]).to eq(user.phone)
      end
    end

    context "密码错误" do
      it "返回认证失败" do
        post "/api/users/login_by_password", params: { phone: user.phone, password: "wrong_password" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("手机号或密码错误")
      end
    end

    context "手机号不存在" do
      it "返回错误" do
        post "/api/users/login_by_password", params: { phone: "19900001111", password: "password123" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("手机号或密码错误")
      end
    end
  end

  # ==================== 重置密码 ====================
  describe "POST /api/users/reset_password" do
    let!(:sms_verification) do
      create(:sms_verification, phone: user.phone, code: "6666", expires_at: 5.minutes.from_now)
    end

    it "通过验证码重置密码成功" do
      post "/api/users/reset_password", params: {
        phone: user.phone, code: "6666", password: "new_password456"
      }

      expect(response).to have_http_status(200).or have_http_status(201)
      expect(json_response[:code]).to eq(0)
    end

    it "重置后可用新密码登录" do
      post "/api/users/reset_password", params: {
        phone: user.phone, code: "6666", password: "new_password456"
      }

      post "/api/users/login_by_password", params: { phone: user.phone, password: "new_password456" }

      expect(json_response[:code]).to eq(0)
      expect(json_response[:data][:token]).to be_present
    end

    context "验证码错误" do
      it "返回错误信息" do
        post "/api/users/reset_password", params: {
          phone: user.phone, code: "0000", password: "new_password456"
        }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("验证码无效或已过期")
      end
    end

    context "验证码已过期" do
      it "返回错误信息" do
        expired_sms = create(:sms_verification, :expired, phone: "13600136000", code: "7777")

        post "/api/users/reset_password", params: {
          phone: "13600136000", code: "7777", password: "new_password456"
        }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("验证码无效或已过期")
      end
    end
  end

  # ==================== 获取用户资料 ====================
  describe "GET /api/users/profile" do
    context "已登录" do
      it "返回用户资料" do
        get "/api/users/profile", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data][:phone]).to eq(user.phone)
        expect(json_response[:data][:nickname]).to be_present
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/users/profile"

        expect(response).to have_http_status(401)
      end
    end

    context "token 已失效" do
      it "返回 401 未授权" do
        invalid_headers = { "Authorization" => "Bearer invalid_token_here" }
        get "/api/users/profile", headers: invalid_headers

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 更新用户资料 ====================
  describe "PUT /api/users/profile" do
    context "已登录" do
      it "更新昵称成功" do
        put "/api/users/profile", params: { nickname: "新昵称" }, headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(user.reload.nickname).to eq("新昵称")
      end

      it "更新头像成功" do
        put "/api/users/profile", params: { avatar: "https://cdn.example.com/new_avatar.jpg" }, headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
      end

      it "更新年级成功" do
        grade = create(:grade)
        put "/api/users/profile", params: { grade_id: grade.id }, headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(user.reload.grade_id).to eq(grade.id)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        put "/api/users/profile", params: { nickname: "新昵称" }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 阅读统计 ====================
  describe "GET /api/users/reading_stats" do
    context "已登录" do
      let(:user) { create(:user, :with_reading_stats) }

      it "返回阅读统计数据" do
        get "/api/users/reading_stats", headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data]).to be_present
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/users/reading_stats"

        expect(response).to have_http_status(401)
      end
    end
  end
end
