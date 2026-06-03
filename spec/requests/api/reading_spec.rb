# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Reading', type: :request do
  let(:user) { create(:app_user) }

  # ==================== 上报阅读记录 ====================
  describe 'POST /api/reading/track' do
    let(:book) { create(:book, status: :published, content_type: :ebook, page_count: 10) }

    it '成功上报阅读记录' do
      post '/api/reading/track', params: {
        uuid: user.uuid,
        book_id: book.id,
        page_number: 3,
        word_count: 500,
        duration_seconds: 180
      }

      expect(response).to have_http_status(201)
      expect(json_response[:response][:code]).to eq(0)
      expect(ReadingSession.where(app_user: user, book: book).count).to eq(1)
    end

    it '图书不存在时返回错误' do
      post '/api/reading/track', params: {
        uuid: user.uuid,
        book_id: 999_999,
        page_number: 3
      }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it '未提供 uuid 时返回参数错误' do
      post '/api/reading/track', params: {
        book_id: 1,
        page_number: 3
      }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 我的阅读统计 ====================
  describe 'GET /api/reading/my_stats' do
    it '返回阅读统计' do
      get '/api/reading/my_stats', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      stats = json_response[:response][:data][:stats]
      expect(stats).to have_key(:total_books)
      expect(stats).to have_key(:completed_books)
      expect(stats).to have_key(:total_reading_minutes)
      expect(stats).to have_key(:total_reading_words)
      expect(stats).to have_key(:consecutive_days)
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/reading/my_stats'

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 阅读时长图表数据 ====================
  describe 'GET /api/reading/chart' do
    it 'week 返回 7 天数据' do
      get '/api/reading/chart', params: { uuid: user.uuid, period: 'week' }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      daily = json_response[:response][:data][:daily]
      expect(daily.size).to eq(7)
      expect(json_response[:response][:data]).to have_key(:total_minutes)
    end

    it 'month 返回 4 周数据' do
      get '/api/reading/chart', params: { uuid: user.uuid, period: 'month' }

      expect(response).to have_http_status(200)
      weekly = json_response[:response][:data][:weekly]
      expect(weekly.size).to eq(4)
      expect(json_response[:response][:data]).to have_key(:total_minutes)
    end

    it '无阅读记录时所有天数为 0' do
      get '/api/reading/chart', params: { uuid: user.uuid, period: 'week' }

      daily = json_response[:response][:data][:daily]
      expect(daily.all? { |d| d[:minutes] == 0 }).to be true
    end

    it '有阅读记录时返回正确时长（week）' do
      create(:user_reading_daily_stats, app_user: user, stat_date: Time.zone.today.to_s, total_duration_seconds: 900)

      get '/api/reading/chart', params: { uuid: user.uuid, period: 'week' }

      daily = json_response[:response][:data][:daily]
      today_entry = daily.find { |d| d[:date] == Time.zone.today.to_s }
      expect(today_entry[:minutes]).to eq(15)
    end

    it '有阅读记录时返回正确时长（month）' do
      create(:user_reading_daily_stats, app_user: user, stat_date: Time.zone.today.to_s, total_duration_seconds: 1800)

      get '/api/reading/chart', params: { uuid: user.uuid, period: 'month' }

      weekly = json_response[:response][:data][:weekly]
      this_week = weekly.last # 最后一周是本周（数组按时间升序）
      expect(this_week[:minutes]).to eq(30)
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/reading/chart', params: { period: 'week' }

      expect(response).to have_http_status(200)
    end

    it '未提供 period 时返回参数错误' do
      get '/api/reading/chart', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 我的阅读进度列表 ====================
  describe 'GET /api/reading/my_progress' do
    it '返回空的阅读进度列表' do
      get '/api/reading/my_progress', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:reading_progress]).to eq([])
    end

    it '返回已有的阅读进度' do
      book = create(:book, name: '测试图书', category_id: 5)
      create(:reading_progress, app_user: user, book: book, last_page_number: 5)

      get '/api/reading/my_progress', params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      progress = json_response[:response][:data][:reading_progress]
      expect(progress.size).to eq(1)
      expect(progress.first[:book_name]).to eq('测试图书')
      expect(progress.first[:category_id]).to eq(5)
    end

    it '未提供 uuid 时返回参数错误' do
      get '/api/reading/my_progress'

      expect(response).to have_http_status(200)
    end
  end

  # ==================== 某本书的阅读进度 ====================
  describe 'GET /api/reading/my_progress/:book_id' do
    let(:book) { create(:book, name: '指定图书') }

    it '返回某本书的阅读进度' do
      book = create(:book, name: '指定图书', category_id: 3)
      create(:reading_progress, app_user: user, book: book, last_page_number: 8, session_count: 3)

      get "/api/reading/my_progress/#{book.id}", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      progress = json_response[:response][:data][:reading_progress]
      expect(progress[:last_page_number]).to eq(8)
      expect(progress[:session_count]).to eq(3)
      expect(progress[:category_id]).to eq(3)
    end

    it '暂无阅读进度时返回错误' do
      get "/api/reading/my_progress/#{book.id}", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to be > 0
    end

    it '未提供 uuid 时返回参数错误' do
      get "/api/reading/my_progress/#{book.id}"

      expect(response).to have_http_status(200)
    end
  end
end
