# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "API Feedback", type: :request do
  let(:user) { create(:app_user) }
  let(:auth_params) { { uuid: user.uuid } }

  describe "POST /api/feedback" do
    context "when logged in" do
      it "submits feedback successfully" do
        post '/api/feedback', params: auth_params.merge(
          type: 'bug',
          content: '页面加载很慢'
        )

        expect(response).to have_http_status(201)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:response][:code]).to eq(0)
        expect(body[:response][:data][:feedback][:content]).to eq('页面加载很慢')
        expect(body[:response][:data][:feedback][:type]).to eq('bug')
        expect(body[:response][:data][:feedback][:type_name]).to eq('功能问题')
      end

      it "submits feedback with images" do
        post '/api/feedback', params: auth_params.merge(
          type: 'content_suggestion',
          content: '建议加一些书',
          images: ['https://example.com/img1.jpg', 'https://example.com/img2.jpg']
        )

        expect(response).to have_http_status(201)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:response][:data][:feedback][:images].length).to eq(2)
      end

      it "rejects empty content" do
        post '/api/feedback', params: auth_params.merge(
          type: 'bug',
          content: ''
        )

        expect(response).to have_http_status(200)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:response][:code]).to be > 0
      end

      it "rejects content over 500 chars" do
        post '/api/feedback', params: auth_params.merge(
          type: 'bug',
          content: 'a' * 501
        )

        expect(response).to have_http_status(200)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:response][:code]).to be > 0
      end

      it "rejects more than 3 images" do
        post '/api/feedback', params: auth_params.merge(
          type: 'bug',
          content: 'test',
          images: ['url1', 'url2', 'url3', 'url4']
        )

        expect(response).to have_http_status(200)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:response][:code]).to be > 0
      end

      it "rejects invalid type" do
        post '/api/feedback', params: auth_params.merge(
          type: 'invalid_type',
          content: 'test'
        )

        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:response][:code]).to eq(1002)
      end
    end

    context "when not logged in" do
      it "returns unauthorized" do
        post '/api/feedback', params: { uuid: 'invalid' }

        expect(response).to have_http_status(200)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:response][:code]).to eq(1002)
      end
    end
  end

  describe "GET /api/feedback/list" do
    it "returns user feedback list" do
      create(:feedback, app_user: user, content: '第一条反馈')
      create(:feedback, :content_suggestion, app_user: user, content: '第二条反馈')

      get '/api/feedback/list', params: auth_params

      expect(response).to have_http_status(200)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:code]).to eq(0)
      expect(body[:response][:data][:feedbacks].length).to eq(2)
    end

    it "only returns own feedbacks" do
      other_user = create(:app_user)
      create(:feedback, app_user: user, content: '我的反馈')
      create(:feedback, app_user: other_user, content: '别人的反馈')

      get '/api/feedback/list', params: auth_params

      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:data][:feedbacks].length).to eq(1)
      expect(body[:response][:data][:feedbacks].first[:content]).to eq('我的反馈')
    end

    it "returns paginated results" do
      5.times { |i| create(:feedback, app_user: user, content: "反馈#{i + 1}") }

      get '/api/feedback/list', params: auth_params.merge(page: 1, per_page: 2)

      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:response][:data][:feedbacks].length).to eq(2)
      expect(body[:response][:data][:pagination][:total_count]).to eq(5)
    end
  end
end
