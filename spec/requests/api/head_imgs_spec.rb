# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API HeadImgs", type: :request do
  let(:user) { create(:app_user) }

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
      user.update!(is_vip: true, vip_expires_at: 30.days.from_now)

      get "/api/head_imgs/index", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      head_imgs = json_response[:response][:data][:head_imgs]
      ids = head_imgs.map { |h| h[:id] }
      expect(ids).to include(normal_img.id)
      expect(ids).to include(vip_img.id)
    end

    it "VIP已过期用户只返回非VIP头像" do
      vip_img = create(:head_img, is_vip: true)
      normal_img = create(:head_img, is_vip: false)
      user.update!(is_vip: true, vip_expires_at: 1.day.ago)

      get "/api/head_imgs/index", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      head_imgs = json_response[:response][:data][:head_imgs]
      expect(head_imgs.map { |h| h[:id] }).to include(normal_img.id)
      expect(head_imgs.map { |h| h[:id] }).not_to include(vip_img.id)
    end

    it "头像 URL 签名有效期为一年" do
      normal_img = create(:head_img, img_url: "https://zheli.oss-cn-beijing.aliyuncs.com/test/avatar.png")

      get "/api/head_imgs/index", params: { uuid: user.uuid }

      head_img = json_response[:response][:data][:head_imgs].first
      expires = head_img[:img_url].match(/Expires=(\d+)/)
      expect(expires).to be_present
      expires_at = expires[1].to_i
      expect(expires_at).to be > (Time.now + 4 * 365 * 24 * 3600).to_i
    end
  end
end
