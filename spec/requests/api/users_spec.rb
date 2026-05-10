# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Users", type: :request do
  let(:user) { create(:app_user, phone: "13800138000", password: "password123") }
  let(:headers) { auth_headers(user) }

  # ==================== 发送验证码 ====================
  describe "POST /api/app_users/send_code" do
    let(:user_with_device_id) { create(:app_user, phone: "13800138000", device_id: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4") }

    before do
      allow_any_instance_of(AliyunSmsService).to receive(:send_verification_code).and_return(true)
    end

    context "手机号格式正确" do
      it "发送验证码成功" do
        post "/api/app_users/send_code", params: { device_id: user_with_device_id.device_id, phone: "13800138001" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:expires_in]).to eq(300)
      end

      it "创建短信验证记录" do
        expect do
          post "/api/app_users/send_code", params: { device_id: user_with_device_id.device_id, phone: "13800138001" }
        end.to change(SmsVerification, :count).by(1)
      end
    end

    context "手机号格式不正确" do
      it "返回参数错误" do
        post "/api/app_users/send_code", params: { device_id: user_with_device_id.device_id, phone: "123" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("手机号格式不正确")
        expect(json_response[:response][:data]).to be_nil
      end
    end

    context "缺少手机号参数" do
      it "返回参数错误" do
        post "/api/app_users/send_code", params: {}

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "device_id 无效" do
      it "返回未授权错误" do
        post "/api/app_users/send_code", params: { device_id: "invalid_device_id", phone: "13800138001" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
        expect(json_response[:response][:msg]).to eq("未授权访问")
      end
    end

    context "device_id 为空字符串" do
      it "发送验证码成功（跳过授权）" do
        post "/api/app_users/send_code", params: { device_id: "", phone: "13800138001" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
      end
    end

    context "不提供 device_id" do
      it "返回参数错误" do
        post "/api/app_users/send_code", params: { phone: "13800138002" }

        expect(response).to have_http_status(:bad_request)
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
        post "/api/app_users/login_by_code", params: { device_id: user.device_id, phone: "13800138000", code: "1234" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user]).to be_present
      end
    end

    context "未授权的设备" do
      it "返回未授权错误" do
        post "/api/app_users/login_by_code", params: { device_id: "invalid_device_id", phone: "13800138000", code: "1234" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
        expect(json_response[:response][:msg]).to eq("未授权访问")
      end
    end

    context "验证码错误" do
      it "返回错误信息" do
        post "/api/app_users/login_by_code", params: { device_id: user.device_id, phone: "13800138000", code: "9999" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("验证码无效或已过期")
      end
    end

    context "手机号未注册" do
      let(:user_without_phone) { create(:app_user, phone: nil) }

      it "绑定新手机号到当前设备用户" do
        new_phone = "13900139000"
        create(:sms_verification, phone: new_phone, code: "5678", expires_at: 5.minutes.from_now)

        post "/api/app_users/login_by_code", params: { device_id: user_without_phone.device_id, phone: new_phone, code: "5678" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        user_without_phone.reload
        expect(user_without_phone.phone).to eq(new_phone)
      end
    end

    context "验证码已过期" do
      it "返回错误信息" do
        create(:sms_verification, :expired, phone: "13700137000", code: "4321")

        post "/api/app_users/login_by_code", params: { device_id: user.device_id, phone: "13700137000", code: "4321" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("验证码无效或已过期")
      end
    end
  end

  # ==================== 密码登录 ====================
  describe "POST /api/app_users/login_by_password" do
    context "密码正确" do
      it "登录成功" do
        post "/api/app_users/login_by_password", params: { device_id: user.device_id, phone: user.phone, password: "password123" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user]).to be_present
        expect(json_response[:response][:data][:user][:phone]).to eq(user.phone)
      end
    end

    context "未授权的设备" do
      it "返回未授权错误" do
        post "/api/app_users/login_by_password", params: { device_id: "invalid_device_id", phone: user.phone, password: "password123" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
        expect(json_response[:response][:msg]).to eq("未授权访问")
      end
    end

    context "密码错误" do
      it "返回认证失败" do
        post "/api/app_users/login_by_password", params: { device_id: user.device_id, phone: user.phone, password: "wrong_password" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("手机号或密码错误")
      end
    end

    context "手机号不存在" do
      it "返回错误" do
        post "/api/app_users/login_by_password", params: { device_id: user.device_id, phone: "19900001111", password: "password123" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("手机号或密码错误")
      end
    end
  end

  # ==================== 微信登录 ====================
  describe "POST /api/app_users/login_by_wechat" do
    let(:wechat_code) { "wechat_auth_code_123" }
    let(:wechat_openid) { "oABC1234567890xyz" }

    around do |example|
      ENV["WECHAT_APP_ID"] = "wx_test_id"
      ENV["WECHAT_APP_SECRET"] = "wx_test_secret"
      example.run
      ENV.delete("WECHAT_APP_ID")
      ENV.delete("WECHAT_APP_SECRET")
    end

    before do
      allow_any_instance_of(WechatAuthService).to receive(:get_openid).with(wechat_code).and_return(wechat_openid)
    end

    context "首次微信登录" do
      it "绑定微信openid到当前设备用户" do
        post "/api/app_users/login_by_wechat", params: { device_id: user.device_id, code: wechat_code }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        user.reload
        expect(user.wechat_openid).to eq(wechat_openid)
      end
    end

    context "未授权的设备" do
      it "返回未授权错误" do
        post "/api/app_users/login_by_wechat", params: { device_id: "invalid_device_id", code: wechat_code }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
        expect(json_response[:response][:msg]).to eq("未授权访问")
      end
    end

    context "微信code无效" do
      it "返回错误" do
        allow_any_instance_of(WechatAuthService).to receive(:get_openid).with("bad_code").and_raise(StandardError, "invalid code")

        post "/api/app_users/login_by_wechat", params: { device_id: user.device_id, code: "bad_code" }

        expect(response).to have_http_status(500)
      end
    end
  end

  # ==================== QQ登录 ====================
  describe "POST /api/app_users/login_by_qq" do
    let(:qq_code) { "qq_auth_code_456" }
    let(:qq_openid) { "QQ_OPENID_ABC123" }

    around do |example|
      ENV["QQ_APP_ID"] = "qq_test_id"
      ENV["QQ_APP_KEY"] = "qq_test_key"
      example.run
      ENV.delete("QQ_APP_ID")
      ENV.delete("QQ_APP_KEY")
    end

    before do
      allow_any_instance_of(QqAuthService).to receive(:get_openid_by_code).with(qq_code).and_return(qq_openid)
    end

    context "首次QQ登录" do
      it "绑定QQopenid到当前设备用户" do
        post "/api/app_users/login_by_qq", params: { device_id: user.device_id, code: qq_code }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        user.reload
        expect(user.qq_openid).to eq(qq_openid)
      end
    end

    context "未授权的设备" do
      it "返回未授权错误" do
        post "/api/app_users/login_by_qq", params: { device_id: "invalid_device_id", code: qq_code }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
        expect(json_response[:response][:msg]).to eq("未授权访问")
      end
    end

    context "QQcode无效" do
      it "返回错误" do
        allow_any_instance_of(QqAuthService).to receive(:get_openid_by_code).with("bad_code").and_raise(StandardError, "invalid code")

        post "/api/app_users/login_by_qq", params: { device_id: user.device_id, code: "bad_code" }

        expect(response).to have_http_status(500)
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
        device_id: user.device_id, phone: user.phone, code: "6666", password: "new_password456"
      }

      expect(response).to have_http_status(200).or have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "未授权的设备返回错误" do
      post "/api/app_users/reset_password", params: {
        device_id: "invalid_device_id", phone: user.phone, code: "6666", password: "new_password456"
      }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(1002)
      expect(json_response[:response][:msg]).to eq("未授权访问")
    end

    it "重置后可用新密码登录" do
      post "/api/app_users/reset_password", params: {
        device_id: user.device_id, phone: user.phone, code: "6666", password: "new_password456"
      }

      post "/api/app_users/login_by_password", params: { device_id: user.device_id, phone: user.phone, password: "new_password456" }

      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:user]).to be_present
    end

    context "验证码错误" do
      it "返回错误信息" do
        post "/api/app_users/reset_password", params: {
          device_id: user.device_id, phone: user.phone, code: "0000", password: "new_password456"
        }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("验证码无效或已过期")
      end
    end

    context "验证码已过期" do
      it "返回错误信息" do
        create(:sms_verification, :expired, phone: "13600136000", code: "7777")

        post "/api/app_users/reset_password", params: {
          device_id: user.device_id, phone: "13600136000", code: "7777", password: "new_password456"
        }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("验证码无效或已过期")
      end
    end
  end

  # ==================== 更新用户资料 ====================
  describe "PUT /api/app_users/update_profile" do
    context "更新昵称" do
      it "更新昵称成功" do
        put "/api/app_users/update_profile", params: { device_id: user.device_id, nickname: "小明同学" }

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:nickname]).to eq("小明同学")
      end
    end

    context "未传昵称" do
      it "返回错误信息" do
        put "/api/app_users/update_profile", params: { device_id: user.device_id }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1001)
        expect(json_response[:response][:msg]).to eq("没有需要更新的字段")
      end
    end

    context "未授权的设备" do
      it "返回未授权错误" do
        put "/api/app_users/update_profile", params: { device_id: "invalid_device_id", nickname: "test" }

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(1002)
        expect(json_response[:response][:msg]).to eq("未授权访问")
      end
    end
  end
end
