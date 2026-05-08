# frozen_string_literal: true

require "rails_helper"

RSpec.describe WechatAuthService do
  let(:app_id) { "wx_test_app_id" }
  let(:app_secret) { "wx_test_app_secret" }

  before do
    ENV["WECHAT_APP_ID"] = app_id
    ENV["WECHAT_APP_SECRET"] = app_secret
  end

  after do
    ENV.delete("WECHAT_APP_ID")
    ENV.delete("WECHAT_APP_SECRET")
  end

  describe "#get_openid" do
    let(:code) { "wechat_code_abc123" }
    let(:openid) { "oABC1234567890xyz" }

    it "returns openid on success" do
      stub_request(:get, %r{api\.weixin\.qq\.com})
        .to_return(status: 200, body: { openid: openid, access_token: "fake_token", expires_in: 7200 }.to_json)

      result = described_class.new.get_openid(code)
      expect(result).to eq(openid)
    end

    it "raises error when WeChat returns error code" do
      stub_request(:get, %r{api\.weixin\.qq\.com})
        .to_return(status: 200, body: { errcode: 40029, errmsg: "invalid code" }.to_json)

      expect { described_class.new.get_openid(code) }.to raise_error(StandardError, "invalid code")
    end
  end
end
