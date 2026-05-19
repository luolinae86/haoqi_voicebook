# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API HeadImgs", type: :request do
  let(:user) { create(:app_user) }

  # ==================== 随机头像 ====================
  describe "GET /api/head_imgs/random" do
    it "返回普通用户头像" do
      normal_img = create(:head_img, is_vip: false)

      get "/api/head_imgs/random", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:head_img][:id]).to eq(normal_img.id)
      expect(json_response[:response][:data][:head_img][:img_url]).to include("Expires=")
      expect(json_response[:response][:data][:head_img][:is_vip]).to eq(false)
    end

    it "VIP用户返回VIP头像" do
      vip_img = create(:head_img, is_vip: true)
      user.update!(is_vip: true)

      get "/api/head_imgs/random", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:head_img][:id]).to eq(vip_img.id)
      expect(json_response[:response][:data][:head_img][:is_vip]).to eq(true)
    end

    it "没有匹配头像时返回 nil" do
      user.update!(is_vip: true)

      get "/api/head_imgs/random", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:head_img]).to be_nil
    end

    it "未提供 uuid 返回参数错误" do
      get "/api/head_imgs/random", params: {}

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end
  end

  # ==================== 头像列表 ====================
  describe "GET /api/head_imgs/index" do
    it "普通用户只返回非VIP头像" do
      vip_img = create(:head_img, is_vip: true)
      normal_img = create(:head_img, is_vip: false)

      get "/api/head_imgs/index", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      head_imgs = json_response[:response][:data][:head_imgs]
      expect(head_imgs.map { |h| h[:id] }).to include(normal_img.id)
      expect(head_imgs.map { |h| h[:id] }).not_to include(vip_img.id)
    end

    it "VIP用户返回所有头像" do
      vip_img = create(:head_img, is_vip: true)
      normal_img = create(:head_img, is_vip: false)
      user.update!(is_vip: true)

      get "/api/head_imgs/index", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      head_imgs = json_response[:response][:data][:head_imgs]
      ids = head_imgs.map { |h| h[:id] }
      expect(ids).to include(normal_img.id)
      expect(ids).to include(vip_img.id)
    end
  end
end
