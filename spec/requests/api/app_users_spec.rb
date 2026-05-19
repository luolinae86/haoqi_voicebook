# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API AppUsers", type: :request do
  let(:user) { create(:app_user) }

  # ==================== 创建设备用户 ====================
  describe "POST /api/app_users/create_by_device" do
    it "创建新用户并默认三年级" do
      post "/api/app_users/create_by_device",
           params: { device_id: "test-device-123" },
           as: :json

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:code]).to eq(0)
      user_data = body[:data][:user]
      expect(user_data[:uuid]).to be_present

      created_user = AppUser.find_by(uuid: user_data[:uuid])
      expect(created_user.grade_id).to eq(Grade.find_by(name: "三年级")&.id)
    end

    it "已存在设备时返回已有用户" do
      existing_user = create(:app_user)
      device = create(:device, device_id: "existing-device", app_user: existing_user)

      post "/api/app_users/create_by_device",
           params: { device_id: "existing-device" },
           as: :json

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:data][:user][:uuid]).to eq(existing_user.uuid)
    end
  end

  # ==================== 头像签名 ====================
  describe "avatar URL 签名" do
    it "返回带签名的 OSS avatar URL" do
      user.update!(avatar: "https://zheli.oss-cn-beijing.aliyuncs.com/test/avatar.png")

      put "/api/app_users/update_profile",
          params: { uuid: user.uuid, nickname: "测试" },
          as: :json

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:user][:avatar]).to include("Expires=")
      expect(json_response[:response][:data][:user][:avatar]).to include("Signature=")
    end

    it "中文路径的 avatar URL 也能正常签名" do
      user.update!(avatar: "https://zheli.oss-cn-beijing.aliyuncs.com/小老虎历险记/avatar.png")

      put "/api/app_users/update_profile",
          params: { uuid: user.uuid, nickname: "测试" },
          as: :json

      expect(response).to have_http_status(200)
      avatar_url = json_response[:response][:data][:user][:avatar]
      expect(avatar_url).to include("Expires=")
      expect(avatar_url).to include("Signature=")
    end

    it "avatar 为 nil 时返回 nil" do
      user.update!(avatar: nil)

      put "/api/app_users/update_profile",
          params: { uuid: user.uuid, nickname: "测试" },
          as: :json

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:user][:avatar]).to be_nil
    end
  end

  # ==================== 更新用户资料 ====================
  describe "PUT /api/app_users/update_profile" do
    context "更新昵称" do
      it "成功更新昵称" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "新昵称" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:nickname]).to eq("新昵称")
      end

      it "返回更新后的用户信息" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "测试昵称" },
            as: :json

        expect(json_response[:response][:data][:user][:id]).to eq(user.id)
        expect(json_response[:response][:data][:user][:uuid]).to eq(user.uuid)
      end
    end

    context "更新年纪" do
      it "成功更新年纪" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, grade_id: 6 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(6)
      end

      it "可以更新为0岁" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, grade_id: 0 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(0)
      end

      it "可以同时更新昵称和年纪" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "小明", grade_id: 8 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:nickname]).to eq("小明")
        expect(json_response[:response][:data][:user][:grade_id]).to eq(8)
      end
    end

    context "参数校验" do
      it "两个字段都为空时返回错误" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it "只有空字符串昵称时返回错误" do
        put "/api/app_users/update_profile",
            params: { uuid: user.uuid, nickname: "" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "未授权" do
      it "无效uuid返回错误" do
        put "/api/app_users/update_profile",
            params: { uuid: "nonexistent-uuid", nickname: "test" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end
  end

  # ==================== 设置/重置密码 ====================
  describe "POST /api/app_users/reset_password" do
    context "首次设置密码（用户没有密码）" do
      it "只需要 uuid 和 password，不需要手机号和验证码" do
        user = AppUser.create! # 不设置密码
        post "/api/app_users/reset_password",
             params: { uuid: user.uuid, password: "NewPass123" },
             as: :json

        expect(response).to have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.password_digest).to be_present
      end

      it "用户未注册时返回错误" do
        post "/api/app_users/reset_password",
             params: { uuid: "nonexistent-uuid", password: "NewPass123" },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "修改已有密码" do
      it "必须提供手机号和验证码" do
        user = create(:app_user)

        post "/api/app_users/reset_password",
             params: { uuid: user.uuid, password: "NewPass123" },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
        expect(json_response[:response][:msg]).to include("手机号")
      end

      it "提供正确的手机号和验证码后可以修改密码" do
        user = create(:app_user, phone: "13800138000")
        create(:sms_verification, phone: "13800138000", code: "1234")

        post "/api/app_users/reset_password",
             params: {
               uuid: user.uuid,
               password: "NewPass123",
               phone: "13800138000",
               code: "1234"
             },
             as: :json

        expect(response).to have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(user.reload.authenticate("NewPass123")).to eq(user)
      end

      it "验证码错误时返回错误" do
        user = create(:app_user, phone: "13800138000")
        create(:sms_verification, phone: "13800138000", code: "1234")

        post "/api/app_users/reset_password",
             params: {
               uuid: user.uuid,
               password: "NewPass123",
               phone: "13800138000",
               code: "9999"
             },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it "手机号不匹配时返回错误" do
        user = create(:app_user, phone: "13800138000")
        create(:sms_verification, phone: "13900139000", code: "1234")

        post "/api/app_users/reset_password",
             params: {
               uuid: user.uuid,
               password: "NewPass123",
               phone: "13900139000",
               code: "1234"
             },
             as: :json

        expect(response).to have_http_status(200)
      end
    end
  end
end
