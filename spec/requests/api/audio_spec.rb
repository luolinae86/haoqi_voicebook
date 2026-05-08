# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Audio", type: :request do
  let(:user) { create(:app_user) }
  let(:vip_user) { create(:app_user, :vip) }
  let(:headers) { auth_headers(user) }
  let(:vip_headers) { auth_headers(vip_user) }

  let(:audio_book) { create(:book, :audio, status: :published) }
  let!(:album) { create(:audio_album, book: audio_book) }
  let!(:free_episode) { create(:audio_episode, :free, audio_album: album, sort_order: 1) }
  let!(:vip_episode) { create(:audio_episode, :vip_only, audio_album: album, sort_order: 2) }
  let!(:regular_episode) { create(:audio_episode, audio_album: album, sort_order: 3) }

  # ==================== 专辑列表 ====================
  describe "GET /api/audio/albums" do
    it "返回有声专辑列表" do
      get "/api/audio/albums"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
    end

    it "支持分页" do
      get "/api/audio/albums", params: { page: 1, per_page: 10 }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "支持按分类过滤" do
      category = audio_book.category
      get "/api/audio/albums", params: { category_id: category.id }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end

    it "支持按年级过滤" do
      grade = audio_book.grade
      get "/api/audio/albums", params: { grade_id: grade.id }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
    end
  end

  # ==================== 专辑详情 ====================
  describe "GET /api/audio/albums/:id" do
    it "返回专辑详情" do
      get "/api/audio/albums/#{audio_book.id}"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:album][:id]).to eq(audio_book.id)
      expect(json_response[:album][:total_episodes]).to be_present
    end

    it "专辑不存在时返回 404" do
      get "/api/audio/albums/999999"

      expect(response).to have_http_status(404)
    end
  end

  # ==================== 单集列表 ====================
  describe "GET /api/audio/albums/:id/episodes" do
    it "返回单集列表" do
      get "/api/audio/albums/#{audio_book.id}/episodes"

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      expect(json_response[:data].size).to eq(3)
    end

    it "支持分页" do
      get "/api/audio/albums/#{audio_book.id}/episodes", params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(200)
      expect(json_response[:data].size).to be <= 2
    end

    it "单集按排序号排列" do
      get "/api/audio/albums/#{audio_book.id}/episodes"

      sort_orders = json_response[:data].map { |e| e[:sort_order] }
      expect(sort_orders).to eq(sort_orders.sort)
    end
  end

  # ==================== 播放单集 ====================
  describe "GET /api/audio/episodes/:episode_id/play" do
    context "已登录" do
      it "播放免费单集成功" do
        get "/api/audio/episodes/#{free_episode.id}/play", params: { device_id: user.device_id }, headers: headers

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).to eq(0)
      end

      context "VIP 单集" do
        it "VIP 用户可以播放" do
          get "/api/audio/episodes/#{vip_episode.id}/play", params: { device_id: vip_user.device_id }, headers: vip_headers

          expect(response).to have_http_status(200)
          expect(json_response[:response][:code]).to eq(0)
        end

        xit "普通用户无法播放 VIP 单集" do
          get "/api/audio/episodes/#{vip_episode.id}/play", headers: headers

          expect(json_response[:response][:code]).not_to eq(0)
        end
      end

      it "播放后增加播放次数" do
        expect do
          get "/api/audio/episodes/#{free_episode.id}/play", params: { device_id: user.device_id }, headers: headers
        end.to change { free_episode.reload.play_count }.by(1)
      end
    end

    context "未登录" do
      xit "返回 401 未授权" do
        get "/api/audio/episodes/#{free_episode.id}/play"

        expect(response).to have_http_status(401)
      end
    end

    context "单集不存在" do
      it "返回 404" do
        get "/api/audio/episodes/999999/play", params: { device_id: user.device_id }, headers: headers

        expect(response).to have_http_status(404)
      end
    end
  end
end
