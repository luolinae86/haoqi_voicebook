# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::Push::PushApi do
  include Rack::Test::Methods

  let(:app) { Api::Base }
  let(:user) { create(:app_user) }
  let(:device) { create(:device, app_user: user, push_cid: 'test_cid_123') }
  let(:auth_headers) do
    token = user.generate_jwt
    { 'Authorization' => "Bearer #{token}" }
  end

  describe 'POST /api/push/test' do
    it 'sends a push notification with title, body and payload' do
      # 直接调个推 API 测试，mock 服务响应
      allow_any_instance_of(GetuiService).to receive(:push_to_single).and_return(
        { 'code' => 0, 'msg' => 'success' }
      )

      post '/api/push/test', {
        cid: 'test_cid_123',
        title: '这是测试',
        body: '我是矬闪电',
        type: 'notification',
        content: '测试内容'
      }, { 'Content-Type' => 'application/json' }

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['response']['msg']).to eq('推送成功')
      expect(json['response']['data']['title']).to eq('这是测试')
    end

    it 'requires cid parameter' do
      post '/api/push/test', {
        title: 'test',
        body: 'test'
      }, { 'Content-Type' => 'application/json' }

      expect(last_response.status).to eq(400)
    end
  end

  describe 'POST /api/push/send' do
    before { device }

    it 'sends push to user latest device cid' do
      allow_any_instance_of(GetuiService).to receive(:push_to_single).and_return(
        { 'code' => 0, 'msg' => 'success' }
      )

      post '/api/push/send', {
        uuid: user.uuid,
        title: '新订单',
        body: '你有新订单',
        type: 'order',
        content: '订单详情'
      }, auth_headers.merge('Content-Type' => 'application/json')

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['response']['data']['cid']).to eq('test_cid_123')
    end

    it 'returns error when no cid found' do
      user_no_device = create(:app_user)

      post '/api/push/send', {
        uuid: user_no_device.uuid,
        title: 'test',
        body: 'test'
      }, auth_headers.merge('Content-Type' => 'application/json')

      expect(last_response.status).to eq(400)
    end
  end
end
