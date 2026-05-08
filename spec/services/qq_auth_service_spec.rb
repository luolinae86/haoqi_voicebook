# frozen_string_literal: true

require "rails_helper"

RSpec.describe QqAuthService do
  let(:app_id) { "qq_test_app_id" }
  let(:app_key) { "qq_test_app_key" }

  before do
    ENV["QQ_APP_ID"] = app_id
    ENV["QQ_APP_KEY"] = app_key
  end

  after do
    ENV.delete("QQ_APP_ID")
    ENV.delete("QQ_APP_KEY")
  end

  describe "#get_openid_by_code" do
    let(:code) { "qq_code_xyz789" }
    let(:access_token) { "qq_access_token_fake" }
    let(:openid) { "QQ_OPENID_ABC123XYZ" }

    it "returns openid on success" do
      stub_request(:get, %r{graph\.qq\.com/oauth2\.0/token})
        .to_return(status: 200, body: "access_token=#{access_token}&expires_in=7776000&refresh_token=fake_refresh")

      stub_request(:get, %r{graph\.qq\.com/oauth2\.0/me})
        .to_return(status: 200, body: "callback( {\"client_id\":\"#{app_id}\",\"openid\":\"#{openid}\"} );")

      result = described_class.new.get_openid_by_code(code)
      expect(result).to eq(openid)
    end

    it "raises error when QQ returns error in token exchange" do
      stub_request(:get, %r{graph\.qq\.com/oauth2\.0/token})
        .to_return(status: 200, body: "error=100030&error_description=invalid+code")

      expect { described_class.new.get_openid_by_code(code) }.to raise_error(StandardError, /invalid code/)
    end

    it "raises error when QQ returns error in openid exchange" do
      stub_request(:get, %r{graph\.qq\.com/oauth2\.0/token})
        .to_return(status: 200, body: "access_token=#{access_token}&expires_in=7776000")

      stub_request(:get, %r{graph\.qq\.com/oauth2\.0/me})
        .to_return(status: 200, body: "callback( {\"error\":100028,\"error_description\":\"token check fail\"} );")

      expect { described_class.new.get_openid_by_code(code) }.to raise_error(StandardError)
    end
  end

  describe "#get_access_token" do
    it "returns access_token string" do
      stub_request(:get, %r{graph\.qq\.com/oauth2\.0/token})
        .to_return(status: 200, body: "access_token=fake_token&expires_in=7776000&refresh_token=fake")

      result = described_class.new.get_access_token("any_code")
      expect(result).to eq("fake_token")
    end
  end

  describe "#get_openid" do
    it "parses QQ openid from callback format" do
      stub_request(:get, %r{graph\.qq\.com/oauth2\.0/me})
        .to_return(status: 200, body: "callback( {\"client_id\":\"#{app_id}\",\"openid\":\"QQ_OPENID_TEST\"} );")

      result = described_class.new.get_openid("any_token")
      expect(result).to eq("QQ_OPENID_TEST")
    end
  end
end
