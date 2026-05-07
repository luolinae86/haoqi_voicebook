# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API V1 Users", type: :request do
  let(:user) { create(:app_user, phone: "13800138000", password: "password123") }
  let(:headers) { auth_headers(user) }

  # ==================== 发送验证码 ====================
  describe "POST /api/app_users/send_code" do
    let(:user_with_uuid) { create(:app_user, phone: "13800138000", uuid: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4") }

    before do
      allow_any_instance_of(AliyunSmsService).to receive(:send_verification_code).and_return(true)
    end

    context "手机号格式正确" do
      it "发送验证码成功" do
        post "/api/app_users/send_code", params: { uuid: user_with_uuid.uuid, phone: "13800138001" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:expires_in]).to eq(300)
      end

      it "创建短信验证记录" do
        expect {
          post "/api/app_users/send_code", params: { uuid: user_with_uuid.uuid, phone: "13800138001" }
        }.to change(SmsVerification, :count).by(1)
      end
    end

    context "手机号格式不正确" do
      it "返回参数错误" do
        post "/api/app_users/send_code", params: { uuid: user_with_uuid.uuid, phone: "123" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("手机号格式不正确")
        expect(json_response[:response][:data]).to be_nil
      end
    end

    context "缺少手机号参数" do
      it "返回参数错误" do
        post "/api/app_users/send_code", params: {}

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "uuid 无效" do
      it "返回未授权错误" do
        post "/api/app_users/send_code", params: { uuid: "invalid_uuid", phone: "13800138001" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
        expect(json_response[:response][:message]).to eq("未授权访问")
      end
    end

    context "uuid 为空字符串" do
      it "视为不提供 uuid，正常发送验证码" do
        post "/api/app_users/send_code", params: { uuid: "", phone: "13800138001" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end
    end

    context "不提供 uuid" do
      it "正常发送验证码" do
        post "/api/app_users/send_code", params: { phone: "13800138002" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end
    end
  end

  # ==================== 验证码登录 ====================
  describe "POST /api/app_users/login_by_code" do
    let!(:sms_verification) do
      create(:sms_verification, phone: "13800138000", code: "1234", expires_at: 5.minutes.from_now)
    end

    context "验证码正确" do
      it "登录成功" do
        post "/api/app_users/login_by_code", params: { phone: "13800138000", code: "1234" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:user]).to be_present
      end
    end

    context "验证码错误" do
      it "返回错误信息" do
        post "/api/app_users/login_by_code", params: { phone: "13800138000", code: "9999" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("验证码无效或已过期")
      end
    end

    context "手机号未注册" do
      it "自动创建新用户" do
        new_phone = "13900139000"
        create(:sms_verification, phone: new_phone, code: "5678", expires_at: 5.minutes.from_now)

        expect {
          post "/api/app_users/login_by_code", params: { phone: new_phone, code: "5678" }
        }.to change(AppUser, :count).by(1)

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end
    end

    context "验证码已过期" do
      it "返回错误信息" do
        expired_sms = create(:sms_verification, :expired, phone: "13700137000", code: "4321")

        post "/api/app_users/login_by_code", params: { phone: "13700137000", code: "4321" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("验证码无效或已过期")
      end
    end
  end

  # ==================== 密码登录 ====================
  describe "POST /api/app_users/login_by_password" do
    context "密码正确" do
      it "登录成功" do
        post "/api/app_users/login_by_password", params: { phone: user.phone, password: "password123" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:user]).to be_present
        expect(json_response[:user][:phone]).to eq(user.phone)
      end
    end

    context "密码错误" do
      it "返回认证失败" do
        post "/api/app_users/login_by_password", params: { phone: user.phone, password: "wrong_password" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("手机号或密码错误")
      end
    end

    context "手机号不存在" do
      it "返回错误" do
        post "/api/app_users/login_by_password", params: { phone: "19900001111", password: "password123" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("手机号或密码错误")
      end
    end
  end

  # ==================== 重置密码 ====================
  describe "POST /api/app_users/reset_password" do
    let!(:sms_verification) do
      create(:sms_verification, phone: user.phone, code: "6666", expires_at: 5.minutes.from_now)
    end

    it "通过验证码重置密码成功" do
      post "/api/app_users/reset_password", params: {
        phone: user.phone, code: "6666", password: "new_password456"
      }

      expect(response).to have_http_status(200).or have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "重置后可用新密码登录" do
      post "/api/app_users/reset_password", params: {
        phone: user.phone, code: "6666", password: "new_password456"
      }

      post "/api/app_users/login_by_password", params: { phone: user.phone, password: "new_password456" }

      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:user]).to be_present
    end

    context "验证码错误" do
      it "返回错误信息" do
        post "/api/app_users/reset_password", params: {
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

        post "/api/app_users/reset_password", params: {
          phone: "13600136000", code: "7777", password: "new_password456"
        }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:message]).to eq("验证码无效或已过期")
      end
    end
  end
end
