# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Oss", type: :request do
  let(:user) { create(:app_user) }

  # ==================== 获取 STS 临时凭证 ====================
  describe "GET /api/oss/token" do
    let(:sts_client) { instance_double(Aliyun::STS::Client) }
    let(:sts_token) do
      OpenStruct.new(
        access_key_id: "STS.tmp-access-key-id",
        access_key_secret: "STS.tmp-access-key-secret",
        security_token: "STS.tmp-security-token",
        expiration: "2026-05-13T15:00:00Z",
        session_name: "voicebook-oss-1234567890"
      )
    end

    before do
      allow(Aliyun::STS::Client).to receive(:new).and_return(sts_client)
      allow(sts_client).to receive(:assume_role).and_return(sts_token)
    end

    it "返回 OSS STS 临时凭证" do
      get "/api/oss/token", params: { uuid: user.uuid }

      expect(response).to have_http_status(:success)
      expect(json_response[:response][:code]).to eq(0)
      info = json_response[:response][:data][:info]
      expect(info[:end_point]).to eq(OSS_ENDPOINT)
      expect(info[:bucket]).to eq(OSS_BUCKET_NAME)
      expect(info[:access_key_id]).to eq("STS.tmp-access-key-id")
      expect(info[:security_token]).to eq("STS.tmp-security-token")
      expect(info[:expiration]).to be_a(String)
      expect(info[:expiration]).not_to be_empty
    end

    it "未登录时返回未授权错误" do
      get "/api/oss/token", params: { uuid: "invalid-uuid" }

      body = json_response[:response]
      expect(body[:code]).to be > 0
    end
  end
end
