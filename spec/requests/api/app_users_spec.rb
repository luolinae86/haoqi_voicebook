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
end
