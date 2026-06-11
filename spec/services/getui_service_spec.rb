# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GetuiService do
  before do
    stub_const('GE_TUI_APP_ID', 'test_app_id')
    stub_const('GE_TUI_APP_KEY', 'test_app_key')
    stub_const('GE_TUI_MASTER_SECRET', 'test_master_secret')
  end

  def mock_http_response(code: 0, data: {}, msg: 'success')
    body = { 'code' => code, 'data' => data, 'msg' => msg }.to_json
    response = instance_double(Net::HTTPResponse)
    allow(response).to receive(:body).and_return(body)
    response
  end

  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    # auth endpoint returns token
    auth_response = mock_http_response(data: { 'token' => 'test_token', 'expire_time' => (Time.now.to_i * 1000 + 86_400_000).to_s })
    # push endpoints return success
    push_response = mock_http_response
    allow(http).to receive(:request) do |req|
      if req.path.include?('auth')
        auth_response
      else
        push_response
      end
    end
  end

  describe '#push_to_single' do
    it 'sends a push to a single cid' do
      service = GetuiService.new
      result = service.push_to_single('cid_123', 'Title', 'Body')

      expect(result['code']).to eq(0)
    end

    it 'raises error when cid is blank' do
      service = GetuiService.new
      expect { service.push_to_single('', 'Title', 'Body') }.to raise_error(ArgumentError, 'cid 不能为空')
    end

    it 'raises PushError on API failure' do
      allow(http).to receive(:request).and_return(mock_http_response(code: 1, msg: 'invalid cid'))
      service = GetuiService.new
      expect { service.push_to_single('cid_123', 'Title', 'Body') }.to raise_error(GetuiService::PushError)
    end
  end

  describe '#push_to_batch' do
    it 'returns empty hash for empty cid list' do
      service = GetuiService.new
      expect(service.push_to_batch([], 'Title', 'Body')).to eq({})
    end

    it 'returns empty hash for nil cid list' do
      service = GetuiService.new
      expect(service.push_to_batch(nil, 'Title', 'Body')).to eq({})
    end

    it 'sends batch push request' do
      service = GetuiService.new
      result = service.push_to_batch(%w[cid_1 cid_2], 'Title', 'Body')

      expect(result['code']).to eq(0)
    end
  end

  describe '#push_to_all' do
    it 'sends a push to all users' do
      service = GetuiService.new
      result = service.push_to_all('Title', 'Body')

      expect(result['code']).to eq(0)
    end

    it 'raises PushError on API failure' do
      allow(http).to receive(:request).and_return(mock_http_response(code: 1, msg: 'app not found'))
      service = GetuiService.new
      expect { service.push_to_all('Title', 'Body') }.to raise_error(GetuiService::PushError)
    end
  end
end
