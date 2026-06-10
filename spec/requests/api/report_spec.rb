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

  describe 'POST /api/report/content_click' do
    it 'records a click event' do
      expect do
        post '/api/report/content_click',
             params: { uuid: user.uuid, book_id: book.id, click_type: 'click' },
             as: :json
      end.to change(ContentClickEvent, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'records a read event with duration' do
      expect do
        post '/api/report/content_click',
             params: { uuid: user.uuid, book_id: book.id, click_type: 'read', duration_seconds: 120 },
             as: :json
      end.to change(ContentClickEvent, :count).by(1)

      event = ContentClickEvent.last
      expect(event.duration_seconds).to eq(120)
    end

    it 'returns error for nonexistent book' do
      post '/api/report/content_click',
           params: { uuid: user.uuid, book_id: 99_999, click_type: 'click' },
           as: :json

      body = json_response[:response]
      expect(body[:code]).to eq(1001)
    end

    it 'returns error for invalid uuid' do
      post '/api/report/content_click',
           params: { uuid: 'invalid_uuid', book_id: book.id, click_type: 'click' },
           as: :json

      body = json_response[:response]
      expect(body[:code]).to eq(1002)
    end
  end

  describe 'POST /api/report/media_play' do
    it 'records a play_start event' do
      expect do
        post '/api/report/media_play',
             params: {
               uuid: user.uuid,
               book_id: book.id,
               chapter_id: chapter.id,
               media_type: 'audio',
               event_type: 'play_start',
               play_seconds: 0,
               total_duration: 600
             },
             as: :json
      end.to change(MediaPlayEvent, :count).by(1)

      expect(response).to have_http_status(:created)
      body = json_response[:response]
      expect(body[:data][:is_valid_play]).to be false
    end

    it 'marks play as valid when >= 10 seconds' do
      post '/api/report/media_play',
           params: {
             uuid: user.uuid,
             book_id: book.id,
             chapter_id: chapter.id,
             media_type: 'audio',
             event_type: 'play_resume',
             play_seconds: 30,
             total_duration: 600
           },
           as: :json

      body = json_response[:response]
      expect(body[:data][:is_valid_play]).to be true
    end

    it 'marks reading progress as completed when play >= 80%' do
      post '/api/report/media_play',
           params: {
             uuid: user.uuid,
             book_id: book.id,
             chapter_id: chapter.id,
             media_type: 'audio',
             event_type: 'play_complete',
             play_seconds: 500,
             total_duration: 600
           },
           as: :json

      progress = ReadingProgress.find_by(app_user_id: user.id, book_id: book.id)
      expect(progress).to be_present
      expect(progress.completed).to be true
    end

    it 'returns error for nonexistent chapter' do
      post '/api/report/media_play',
           params: {
             uuid: user.uuid,
             book_id: book.id,
             chapter_id: 99_999,
             media_type: 'audio',
             event_type: 'play_start'
           },
           as: :json

      body = json_response[:response]
      expect(body[:code]).to eq(1001)
    end
  end
end
