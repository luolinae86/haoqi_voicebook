# frozen_string_literal: true

require "rails_helper"

RSpec.xdescribe "API Memberships", type: :request do
  let(:user) { create(:app_user) }
  let(:headers) { auth_headers(user) }

  # ==================== 会员套餐 ====================
  describe "GET /api/memberships/plans" do
    it "返回会员套餐列表" do
      get "/api/memberships/plans"

      expect(response).to have_http_status(200)
      expect(json_response[:code]).to eq(0)
      expect(json_response[:data]).to be_an(Array)
      expect(json_response[:data]).not_to be_empty
    end

    it "包含月度、季度、年度套餐" do
      get "/api/memberships/plans"

      plan_types = json_response[:data].map { |p| p[:plan_type] }
      expect(plan_types).to include("monthly", "quarterly", "annual")
    end

    it "每个套餐包含价格信息" do
      get "/api/memberships/plans"

      json_response[:data].each do |plan|
        expect(plan[:price]).to be_present
      end
    end
  end

  # ==================== 购买会员 ====================
  describe "POST /api/memberships/purchase" do
    context "已登录" do
      it "创建月度会员订单" do
        post "/api/memberships/purchase",
             params: { plan_type: "monthly", payment_method: "wechat" },
             headers: headers

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
        expect(json_response[:data][:order_no]).to be_present
        expect(json_response[:data][:amount]).to be_present
      end

      it "创建季度会员订单" do
        post "/api/memberships/purchase",
             params: { plan_type: "quarterly", payment_method: "alipay" },
             headers: headers

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "创建年度会员订单" do
        post "/api/memberships/purchase",
             params: { plan_type: "annual", payment_method: "wechat" },
             headers: headers

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
      end

      it "生成订单记录" do
        expect {
          post "/api/memberships/purchase",
               params: { plan_type: "monthly", payment_method: "wechat" },
               headers: headers
        }.to change(Order, :count).by(1)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/memberships/purchase",
             params: { plan_type: "monthly", payment_method: "wechat" }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 支付回调 ====================
  describe "POST /api/memberships/payment_callback" do
    context "已登录" do
      let!(:membership) { create(:membership, :pending, app_user: user) }
      let!(:order) { create(:order, app_user: user, status: :pending, membership: membership) }

      it "支付回调成功激活会员" do
        post "/api/memberships/payment_callback",
             params: { order_no: order.order_no },
             headers: headers

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:code]).to eq(0)
        expect(order.reload.status).to eq("paid")
      end

      it "用户 VIP 状态被激活" do
        post "/api/memberships/payment_callback",
             params: { order_no: order.order_no },
             headers: headers

        expect(user.reload.is_vip).to be true
        expect(user.reload.vip_expires_at).to be > Time.current
      end

      it "订单号不存在返回错误" do
        post "/api/memberships/payment_callback",
             params: { order_no: "INVALID_ORDER_NO" },
             headers: headers

        expect(json_response[:code]).not_to eq(0)
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        post "/api/memberships/payment_callback",
             params: { order_no: "ORD123" }

        expect(response).to have_http_status(401)
      end
    end
  end

  # ==================== 我的会员 ====================
  describe "GET /api/memberships/my" do
    context "已登录" do
      context "是 VIP 用户" do
        let(:vip_user) { create(:app_user, :vip) }
        let(:vip_headers) { auth_headers(vip_user) }

        before do
          create(:membership, app_user: vip_user, status: :active)
        end

        it "返回会员信息" do
          get "/api/memberships/my", headers: vip_headers

          expect(response).to have_http_status(200)
          expect(json_response[:code]).to eq(0)
          expect(json_response[:data]).to be_present
        end
      end

      context "不是 VIP 用户" do
        it "返回无会员状态" do
          get "/api/memberships/my", headers: headers

          expect(response).to have_http_status(200)
          expect(json_response[:code]).to eq(0)
        end
      end
    end

    context "未登录" do
      it "返回 401 未授权" do
        get "/api/memberships/my"

        expect(response).to have_http_status(401)
      end
    end
  end
end
