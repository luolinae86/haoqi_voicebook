# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Oss", type: :request do
  let(:user) { create(:app_user) }
  let(:oss_service) { instance_double(AliyunOssService) }

  # ==================== 获取签名 URL ====================
  describe "GET /api/oss/signed_url" do
    it "返回 OSS 对象签名 URL" do
      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:generate_signed_url).and_return("https://epub-files.oss-cn-beijing.aliyuncs.com/test.pdf?Signature=xxx&Expires=1234567890&OSSAccessKeyId=xxx")

      get "/api/oss/signed_url", params: {
        uuid: user.uuid,
        object_key: "test.pdf",
        expires: 3600
      }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:signed_url]).to include("Signature=")
    end

    it "未登录时返回未授权错误" do
      get "/api/oss/signed_url", params: {
        uuid: "invalid-uuid",
        object_key: "test.pdf"
      }

      body = json_response[:response]
      expect(body[:code]).to be > 0
    end

    it "object_key 缺失时返回参数错误" do
      get "/api/oss/signed_url", params: {
        uuid: user.uuid
      }

      expect(response).to have_http_status(400)
    end

    it "签名失败时返回错误" do
      allow(AliyunOssService).to receive(:new).and_return(oss_service)
      allow(oss_service).to receive(:generate_signed_url).and_raise(AliyunOssService::UploadError, "OSS 签名失败: bucket 不存在")

      get "/api/oss/signed_url", params: {
        uuid: user.uuid,
        object_key: "nonexistent.pdf"
      }

      expect(response).to have_http_status(:success)
      body = json_response[:response]
      expect(body[:code]).to be > 0
      expect(body[:msg]).to include("签名失败")
    end
  end
end
