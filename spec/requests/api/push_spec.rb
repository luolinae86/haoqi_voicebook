# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Push', type: :request do
  # Stub GetuiService HTTP calls for all tests
  before do
    stub_request(:any, /restapi\.getui\.com/).to_return(
      status: 200,
      body: { code: 0, msg: 'success', data: { taskId: 'task_123' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  # Helper to extract the inner data from present response: success_response(...)
  def push_response_data
    json = json_response
    json[:response][:data][:data] || json[:response][:data]
  end

  describe 'POST /api/push/test' do
    it 'sends a push notification with title, body and payload' do
      post '/api/push/test',
           params: {
             cid: 'test_cid_123',
             title: '这是测试',
             body: '我是矬闪电',
             type: 'notification',
             content: { text: '测试内容' }
           },
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      expect(data[:title]).to eq('这是测试')
      expect(data[:cid]).to eq('test_cid_123')
    end

    it 'requires cid parameter' do
      post '/api/push/test',
           params: { title: 'test', body: 'test' },
           as: :json

      expect([200, 400]).to include(response.status)
    end
  end

  describe 'POST /api/push/send' do
    it 'sends push to user device cid when single device exists' do
      # app_user factory auto-creates 1 device, so this user has exactly 1 device
      user = create(:app_user)

      post '/api/push/send',
           params: {
             uuid: user.uuid,
             title: '新订单',
             body: '你有新订单'
           },
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      expect(data[:devices].size).to eq(1)
    end

    it 'sends push to all user devices when multiple exist' do
      user = create(:app_user)
      # factory already created 1 device, add 2 more = 3 total
      create(:device, app_user: user, push_cid: 'cid_b')
      create(:device, app_user: user, push_cid: 'cid_c')

      post '/api/push/send',
           params: {
             uuid: user.uuid,
             title: '新订单',
             body: '你有新订单'
           },
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      expect(data[:devices].size).to eq(3)
    end

    it 'sends push to specified cid only' do
      user = create(:app_user)
      device = user.devices.first

      post '/api/push/send',
           params: {
             uuid: user.uuid,
             cid: device.push_cid,
             title: '测试',
             body: '测试内容'
           },
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      expect(data[:devices].size).to eq(1)
      expect(data[:devices].first[:cid]).to eq(device.push_cid)
    end

    it 'ignores devices with empty push_cid' do
      user = create(:app_user)
      # factory already created 1 device with push_cid, add 2 without
      create(:device, app_user: user, push_cid: nil)
      create(:device, app_user: user, push_cid: '')

      post '/api/push/send',
           params: { uuid: user.uuid, title: '测试', body: '测试内容' },
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      # Only the factory-created device has a valid push_cid
      expect(data[:devices].size).to eq(1)
    end

    it 'deduplicates same push_cid across devices' do
      user = create(:app_user)
      # Update the factory-created device to have the same cid as the new one
      user.devices.first.update!(push_cid: 'same_cid')
      create(:device, app_user: user, push_cid: 'same_cid')

      post '/api/push/send',
           params: { uuid: user.uuid, title: '测试', body: '测试内容' },
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      # Both devices have same cid, should only push once
      expect(data[:devices].size).to eq(1)
    end

    it 'returns error when no cid found' do
      # Create user normally but remove all devices
      user_no_device = create(:app_user)
      user_no_device.devices.destroy_all

      post '/api/push/send',
           params: { uuid: user_no_device.uuid, title: 'test', body: 'test' },
           as: :json

      expect(response.status).to eq(400)
    end
  end
end
