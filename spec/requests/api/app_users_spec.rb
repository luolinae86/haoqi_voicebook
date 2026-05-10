# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API AppUsers", type: :request do
  let(:user) { create(:app_user) }

  # ==================== 更新用户资料 ====================
  describe "PUT /api/app_users/update_profile" do
    context "更新昵称" do
      it "成功更新昵称" do
        put "/api/app_users/update_profile",
            params: { device_id: user.device_id, nickname: "新昵称" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:nickname]).to eq("新昵称")
      end

      it "返回更新后的用户信息" do
        put "/api/app_users/update_profile",
            params: { device_id: user.device_id, nickname: "测试昵称" },
            as: :json

        expect(json_response[:response][:data][:user][:id]).to eq(user.id)
        expect(json_response[:response][:data][:user][:device_id]).to eq(user.device_id)
      end
    end

    context "更新年纪" do
      it "成功更新年纪" do
        put "/api/app_users/update_profile",
            params: { device_id: user.device_id, grade_id: 6 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(6)
      end

      it "可以更新为0岁" do
        put "/api/app_users/update_profile",
            params: { device_id: user.device_id, grade_id: 0 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:grade_id]).to eq(0)
      end

      it "可以同时更新昵称和年纪" do
        put "/api/app_users/update_profile",
            params: { device_id: user.device_id, nickname: "小明", grade_id: 8 },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:data][:user][:nickname]).to eq("小明")
        expect(json_response[:response][:data][:user][:grade_id]).to eq(8)
      end
    end

    context "参数校验" do
      it "两个字段都为空时返回错误" do
        put "/api/app_users/update_profile",
            params: { device_id: user.device_id },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it "只有空字符串昵称时返回错误" do
        put "/api/app_users/update_profile",
            params: { device_id: user.device_id, nickname: "" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end

    context "未授权" do
      it "无效设备ID返回错误" do
        put "/api/app_users/update_profile",
            params: { device_id: "nonexistent-device", nickname: "test" },
            as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end
  end
end
