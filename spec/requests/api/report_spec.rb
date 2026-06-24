# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Report', type: :request do
  let(:user) { create(:app_user) }
  let(:book) { create(:book) }
  let(:chapter) { create(:chapter, book: book, duration: 600) }

  describe 'POST /api/report/app_open' do
    it 'records app open for a user' do
      expect do
        post '/api/report/app_open',
             params: { uuid: user.uuid, channel: 'app_store' },
             as: :json
      end.to change(UserActivityLog, :count).by(1)

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:code]).to eq(0)
    end

    it 'does not duplicate for same user same day' do
      post '/api/report/app_open',
           params: { uuid: user.uuid },
           as: :json

      expect do
        post '/api/report/app_open',
             params: { uuid: user.uuid },
             as: :json
      end.not_to change(UserActivityLog, :count)
    end

    it 'returns error for unregistered user' do
      post '/api/report/app_open',
           params: { uuid: 'nonexistent_uuid' },
           as: :json

      expect(response).to have_http_status(:ok)
      body = json_response[:response]
      expect(body[:code]).to eq(1001)
      expect(body[:msg]).to include('用户未注册')
    end
  end

  describe 'POST /api/report/resource_view' do
    it 'records ebook browse as content_click event' do
      expect do
        post '/api/report/resource_view',
             params: { uuid: user.uuid, book_id: book.id, resource_type: 'ebook', duration_seconds: 5 },
             as: :json
      end.to change(ContentClickEvent, :count).by(1)

      expect(ContentClickEvent.last.click_type).to eq('click')
    end

    it 'marks duration >= 30s as read' do
      post '/api/report/resource_view',
           params: { uuid: user.uuid, book_id: book.id, resource_type: 'ebook', duration_seconds: 45 },
           as: :json

      expect(ContentClickEvent.last.click_type).to eq('read')
    end

    it 'records audio play as media_play event' do
      expect do
        post '/api/report/resource_view',
             params: {
               uuid: user.uuid, book_id: book.id, chapter_id: chapter.id,
               resource_type: 'audio', duration_seconds: 30
             },
             as: :json
      end.to change(MediaPlayEvent, :count).by(1)

      event = MediaPlayEvent.last
      expect(event.is_valid_play).to be true
      expect(event.play_seconds).to eq(30)
      expect(event.total_duration).to eq(600)  # from chapter.duration
    end

    it 'marks play < 10s as invalid' do
      post '/api/report/resource_view',
           params: {
             uuid: user.uuid, book_id: book.id, chapter_id: chapter.id,
             resource_type: 'audio', duration_seconds: 5
           },
           as: :json

      expect(MediaPlayEvent.last.is_valid_play).to be false
    end

    it 'marks reading progress as completed when >= 80%' do
      post '/api/report/resource_view',
           params: {
             uuid: user.uuid, book_id: book.id, chapter_id: chapter.id,
             resource_type: 'audio', duration_seconds: 500,
             is_complete: true
           },
           as: :json

      progress = ReadingProgress.find_by(app_user_id: user.id, book_id: book.id)
      expect(progress).to be_present
      expect(progress.completed).to be true
    end

    it 'returns error for nonexistent book' do
      post '/api/report/resource_view',
           params: { uuid: user.uuid, book_id: 99_999, resource_type: 'ebook' },
           as: :json

      body = json_response[:response]
      expect(body[:code]).to eq(1001)
    end

    it 'returns error for nonexistent chapter when audio/video' do
      post '/api/report/resource_view',
           params: {
             uuid: user.uuid, book_id: book.id, chapter_id: 99_999,
             resource_type: 'audio', duration_seconds: 10
           },
           as: :json

      body = json_response[:response]
      expect(body[:code]).to eq(1001)
    end
  end
end
