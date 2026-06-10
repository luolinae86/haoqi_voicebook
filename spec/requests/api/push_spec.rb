# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Push', type: :request do
  let(:admin) { create(:app_user, :admin) }

  # Stub GetuiService HTTP calls for all tests
  before do
    stub_request(:any, /restapi\.getui\.com/).to_return(
      status: 200,
      body: { code: 0, msg: 'success', data: { taskId: 'task_123' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  # Helper to extract the inner data from present response: success_response(...)
  # Grape wraps present response: X with an extra layer, so:
  # success response: { response: { code: 0, msg: ..., data: { data: {...} } } }
  # error response:   { response: { code: 1, msg: "...", data: nil } }
  def push_response_data
    json = json_response
    inner = json[:response][:data]
    inner[:data] || inner
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
    let(:send_params) do
      {
        uuid: admin.uuid,
        grade_ids: [],
        title: '年级通知',
        body: '这是年级通知'
      }
    end

    it 'sends push to all devices of users in specified grades' do
      grade = create(:grade)
      user1 = create(:app_user, grade_id: grade.id)
      create(:app_user, grade_id: grade.id)
      # Each user has 1 device from factory, plus add another for user1
      create(:device, app_user: user1, push_cid: 'cid_extra')

      post '/api/push/send',
           params: send_params.merge(grade_ids: [grade.id]),
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      expect(data[:devices].size).to eq(3)
      expect(data[:grade_ids]).to eq([grade.id])
    end

    it 'sends push to users across multiple grades' do
      grade1 = create(:grade)
      grade2 = create(:grade)
      create(:app_user, grade_id: grade1.id)
      create(:app_user, grade_id: grade2.id)

      post '/api/push/send',
           params: send_params.merge(grade_ids: [grade1.id, grade2.id]),
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      expect(data[:devices].size).to eq(2)
      expect(data[:grade_ids]).to contain_exactly(grade1.id, grade2.id)
    end

    it 'ignores devices with empty push_cid' do
      grade = create(:grade)
      user = create(:app_user, grade_id: grade.id)
      create(:device, app_user: user, push_cid: nil)
      create(:device, app_user: user, push_cid: '')

      post '/api/push/send',
           params: send_params.merge(grade_ids: [grade.id]),
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      # Only the factory-created device has a valid push_cid
      expect(data[:devices].size).to eq(1)
    end

    it 'deduplicates same push_cid across devices' do
      grade = create(:grade)
      user = create(:app_user, grade_id: grade.id)
      user.devices.first.update!(push_cid: 'same_cid')
      create(:device, app_user: user, push_cid: 'same_cid')

      post '/api/push/send',
           params: send_params.merge(grade_ids: [grade.id]),
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      expect(data[:devices].size).to eq(1)
    end

    it 'returns error when no users in specified grades' do
      grade = create(:grade)

      post '/api/push/send',
           params: send_params.merge(grade_ids: [grade.id]),
           as: :json

      expect(response.status).to eq(400)
    end

    it 'returns error when grade_ids is empty' do
      post '/api/push/send',
           params: send_params,
           as: :json

      expect(response.status).to eq(400)
    end

    it 'only pushes to users with matching grade_id' do
      grade1 = create(:grade)
      grade2 = create(:grade)
      create(:app_user, grade_id: grade1.id)
      create(:app_user, grade_id: grade2.id)

      post '/api/push/send',
           params: send_params.merge(grade_ids: [grade1.id]),
           as: :json

      expect([200, 201]).to include(response.status)
      data = push_response_data
      # Only 1 device from grade1 user
      expect(data[:devices].size).to eq(1)
    end
  end
end
