# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Memberships", type: :request do
  let(:user) { create(:app_user) }

  # ==================== 会员套餐 ====================
  describe "GET /api/memberships/plans" do
    it "返回会员套餐列表" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:plans]).to be_an(Array)
      expect(json_response[:response][:data][:plans].size).to eq(3)
    end

    it "包含月度、季度、年度套餐" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      plan_types = json_response[:response][:data][:plans].map { |p| p[:plan_type] }
      expect(plan_types).to include("monthly", "quarterly", "annual")
    end

    it "每个套餐包含价格信息" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      json_response[:response][:data][:plans].each do |plan|
        expect(plan[:price]).to be_present
        expect(plan[:plan_label]).to be_present
        expect(plan[:original_price]).to be_present
      end
    end

    it "月度会员价格为19.90" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      monthly = json_response[:response][:data][:plans].find { |p| p[:plan_type] == "monthly" }
      expect(monthly[:price]).to eq(19.90)
      expect(monthly[:plan_label]).to eq("月度会员")
    end

    it "年度会员价格为168.00" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      annual = json_response[:response][:data][:plans].find { |p| p[:plan_type] == "annual" }
      expect(annual[:price]).to eq(168.00)
      expect(annual[:plan_label]).to eq("年度会员")
    end
  end

  # ==================== 购买会员 ====================
  describe "POST /api/memberships/create_order" do
    before do
      # 设置测试用支付配置
      private_key = OpenSSL::PKey::RSA.generate(2048)
      ENV["ALIPAY_APP_ID"] = "test_alipay_app"
      ENV["ALIPAY_PRIVATE_KEY"] = private_key.to_pem
      ENV["ALIPAY_PUBLIC_KEY"] = private_key.public_key.to_pem
      ENV["ALIPAY_NOTIFY_URL"] = "https://test.example.com/alipay/notify"

      ENV["WECHAT_APP_ID"] = "test_wechat_app"
      ENV["WECHAT_MCH_ID"] = "1234567890"
      ENV["WECHAT_API_CERT"] = private_key.to_pem
      ENV["WECHAT_API_CERT_SERIAL"] = "test_serial"
      ENV["WECHAT_NOTIFY_URL"] = "https://test.example.com/wechat/notify"

      # 阻止微信支付实际 HTTP 调用，返回 mock 预支付 ID
      stub_request(:post, "https://api.mch.weixin.qq.com/v3/pay/transactions/app")
        .to_return(
          status: 200,
          body: JSON.generate({ prepay_id: "wx_mock_prepay_id" }),
          headers: { "Content-Type" => "application/json" }
        )
    end

    context "已登录" do
      it "创建月度会员订单" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, plan_type: "monthly", payment_method: "wechat" },
             as: :json

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:order][:order_no]).to be_present
        expect(json_response[:response][:data][:order][:amount].to_f).to eq(19.90)
        expect(json_response[:response][:data][:order][:payment_method]).to eq("wechat")
        expect(json_response[:response][:data][:order][:status]).to eq("pending")
        expect(json_response[:response][:data][:payment_params]).to be_a(Hash)
        expect(json_response[:response][:data][:payment_params][:prepayid]).to eq("wx_mock_prepay_id")
      end

      it "创建季度会员订单" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, plan_type: "quarterly", payment_method: "alipay" },
             as: :json

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:order][:amount].to_f).to eq(49.90)
        expect(json_response[:response][:data][:payment_params]).to be_a(String)
        expect(json_response[:response][:data][:payment_params]).to include("test_alipay_app")
      end

      it "创建年度会员订单" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, plan_type: "annual", payment_method: "wechat" },
             as: :json

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:order][:amount].to_f).to eq(168.00)
      end

      it "生成订单记录和会员记录" do
        expect do
          post "/api/memberships/create_order",
               params: { uuid: user.uuid, plan_type: "monthly", payment_method: "wechat" },
               as: :json
        end.to change(Order, :count).by(1)
                                    .and change(Membership, :count).by(1)
      end

      it "会员记录关联订单" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, plan_type: "quarterly", payment_method: "alipay" },
             as: :json

        order = Order.find_by(order_no: json_response[:response][:data][:order][:order_no])
        expect(order.membership).to be_present
        expect(order.membership.plan_type).to eq("quarterly")
        expect(order.membership.status).to eq("pending")
      end
    end

    context "未登录" do
      it "返回未授权" do
        post "/api/memberships/create_order",
             params: { uuid: "nonexistent-uuid", plan_type: "monthly", payment_method: "wechat" },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end
    end
  end

  # ==================== 订阅记录 ====================
  describe "GET /api/memberships/subscriptions" do
    it "返回订阅记录列表" do
      membership = create(:membership, :annual, app_user: user, status: :active)
      create(:order, :paid, app_user: user, membership: membership, amount: 168.00)

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:items]).to be_an(Array)
      expect(json_response[:response][:data][:items].size).to eq(1)
    end

    it "每条记录包含必要字段" do
      membership = create(:membership, :annual, app_user: user, status: :active)
      order = create(:order, :paid, app_user: user, membership: membership, amount: 168.00,
                                    paid_at: Time.zone.parse("2026-05-01 10:30:00"))

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      item = json_response[:response][:data][:items].first
      expect(item[:order_no]).to eq(order.order_no)
      expect(item[:plan_label]).to eq("年度会员")
      expect(item[:price].to_f).to eq(168.00)
      expect(item[:paid_at]).to eq("2026-05-01 10:30:00")
      expect(item).to have_key(:days_left)
      expect(item).to have_key(:expired)
    end

    it "已过期会员显示已过期" do
      membership = create(:membership, :expired, app_user: user)
      create(:order, :paid, app_user: user, membership: membership)

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      item = json_response[:response][:data][:items].first
      expect(item[:expired]).to be true
      expect(item[:days_left]).to eq(0)
    end

    it "有效会员显示剩余天数" do
      membership = create(:membership, :annual, app_user: user, status: :active)
      create(:order, :paid, app_user: user, membership: membership)

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      item = json_response[:response][:data][:items].first
      expect(item[:expired]).to be false
      expect(item[:days_left]).to be >= 360
    end

    it "月度会员显示正确天数" do
      membership = create(:membership, :monthly, app_user: user, status: :active)
      create(:order, :paid, app_user: user, membership: membership)

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      item = json_response[:response][:data][:items].first
      expect(item[:expired]).to be false
      expect(item[:days_left]).to be >= 25
      expect(item[:days_left]).to be <= 31
    end

    it "按创建时间倒序排列" do
      old_membership = create(:membership, :monthly, app_user: user, status: :active,
                                                     created_at: 2.months.ago)
      new_membership = create(:membership, :annual, app_user: user, status: :active,
                                                    created_at: 1.month.ago)
      create(:order, :paid, app_user: user, membership: old_membership,
                            created_at: 2.months.ago)
      create(:order, :paid, app_user: user, membership: new_membership,
                            created_at: 1.month.ago)

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      items = json_response[:response][:data][:items]
      expect(items.size).to eq(2)
      expect(items[0][:plan_label]).to eq("年度会员")
      expect(items[1][:plan_label]).to eq("月度会员")
    end

    it "多条订阅记录全部返回" do
      3.times do |i|
        membership = create(:membership, :monthly, app_user: user, status: :active,
                                                   created_at: i.months.ago)
        create(:order, :paid, app_user: user, membership: membership,
                              created_at: i.months.ago)
      end

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      expect(json_response[:response][:data][:items].size).to eq(3)
    end

    it "无订阅用户返回空数组" do
      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      expect(json_response[:response][:data][:items]).to eq([])
    end

    it "未授权用户返回错误" do
      get "/api/memberships/subscriptions", params: { uuid: "nonexistent-uuid" }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).not_to eq(0)
    end

    it "只返回已支付的订单" do
      membership = create(:membership, :monthly, app_user: user, status: :active)
      create(:order, :paid, app_user: user, membership: membership)
      create(:order, status: :pending, app_user: user, membership: create(:membership, :monthly, app_user: user))
      create(:order, :failed, app_user: user, membership: create(:membership, :monthly, app_user: user))

      get "/api/memberships/subscriptions", params: { uuid: user.uuid }

      expect(json_response[:response][:data][:items].size).to eq(1)
    end
  end

  # ==================== 支付回调 ====================
  describe "POST /api/memberships/alipay_callback" do
    it "返回 success 当签名验证成功且支付成功" do
      private_key = OpenSSL::PKey::RSA.generate(2048)
      ENV["ALIPAY_PUBLIC_KEY"] = private_key.public_key.to_pem

      order = create(:order, status: :pending, membership: create(:membership, status: :pending))

      params = {
        out_trade_no: order.order_no,
        trade_status: "TRADE_SUCCESS",
        total_amount: "19.90"
      }

      string_to_sign = params.sort.map { |k, v| "#{k}=#{v}" }.join("&")
      signature = Base64.strict_encode64(private_key.sign(OpenSSL::Digest.new("SHA256"), string_to_sign))
      params[:sign] = signature
      params[:sign_type] = "RSA2"

      post "/api/memberships/alipay_callback", params: params

      expect(response.body).to include("success")
    end

    it "返回 failure 当签名验证失败" do
      post "/api/memberships/alipay_callback",
           params: { out_trade_no: "test", trade_status: "TRADE_SUCCESS", sign: "bad", sign_type: "RSA2" }

      expect(response.body).to include("failure")
    end
  end
end
