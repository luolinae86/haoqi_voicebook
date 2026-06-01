# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Memberships", type: :request do
  let(:user) { create(:app_user) }

  # ==================== 会员套餐 ====================
  describe "GET /api/memberships/plans" do
    before do
      create(:package, name: "季套餐包", price: 59.9, origin_price: 59.9, effective_days: 90)
      create(:package, name: "月套餐", price: 19.9, origin_price: 19.9, effective_days: 30)
      create(:package, name: "年套餐", price: 168.0, origin_price: 358.8, effective_days: 365)
    end

    it "返回套餐列表，按价格降序排列" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:code]).to eq(0)
      packages = json_response[:response][:data][:packages]
      expect(packages.size).to eq(3)
      expect(packages.map { |p| p[:price] }).to eq([168.0, 59.9, 19.9])
    end

    it "金额最大的套餐返回在最前面" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      packages = json_response[:response][:data][:packages]
      expect(packages.first[:name]).to eq("年套餐")
    end

    it "每个套餐包含必要字段" do
      get "/api/memberships/plans", params: { uuid: user.uuid }

      json_response[:response][:data][:packages].each do |pkg|
        expect(pkg[:id]).to be_present
        expect(pkg[:name]).to be_present
        expect(pkg[:price]).to be_present
        expect(pkg[:origin_price]).to be_present
        expect(pkg[:effective_days]).to be_present
        expect(pkg).to have_key(:is_discount)
        expect(pkg).to have_key(:discount_tag)
      end
    end

    it "无套餐时返回空数组" do
      Package.where(is_delete: false).destroy_all

      get "/api/memberships/plans", params: { uuid: user.uuid }

      expect(response).to have_http_status(200)
      expect(json_response[:response][:data][:packages]).to eq([])
    end
  end

  # ==================== 购买会员 ====================
  describe "POST /api/memberships/create_order" do
    let(:package) { create(:package, name: "月套餐", price: 19.9, origin_price: 29.9, effective_days: 30) }

    before do
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

      stub_request(:post, "https://api.mch.weixin.qq.com/v3/pay/transactions/app")
        .to_return(
          status: 200,
          body: JSON.generate({ prepay_id: "wx_mock_prepay_id" }),
          headers: { "Content-Type" => "application/json" }
        )
    end

    context "已登录" do
      it "创建订单" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: package.id, payment_method: "wechat" },
             as: :json

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:order][:order_no]).to be_present
        expect(json_response[:response][:data][:order][:amount].to_f).to eq(19.9)
        expect(json_response[:response][:data][:order][:payment_method]).to eq("wechat")
        expect(json_response[:response][:data][:order][:status]).to eq("pending")
        expect(json_response[:response][:data][:payment_params]).to be_a(Hash)
        expect(json_response[:response][:data][:payment_params][:prepayid]).to eq("wx_mock_prepay_id")
      end

      it "支付宝支付返回 payment_params 支付字符串" do
        # 配置支付宝测试密钥
        private_key = OpenSSL::PKey::RSA.generate(2048)
        ENV["ALIPAY_PRIVATE_KEY"] = private_key.to_pem

        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: package.id, payment_method: "alipay" },
             as: :json

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)

        data = json_response[:response][:data]
        expect(data[:payment_params]).to be_a(String)
        expect(data[:payment_params]).to include("sign=")
        expect(data[:payment_params]).to include("biz_content")
        expect(data[:order][:payment_method]).to eq("alipay")
      end

      it "微信支付返回 payment_params Hash" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: package.id, payment_method: "wechat" },
             as: :json

        data = json_response[:response][:data]
        expect(data[:payment_params]).to be_a(Hash)
        expect(data[:payment_params]).to have_key(:appid)
        expect(data[:payment_params]).to have_key(:prepayid)
        expect(data[:payment_params]).to have_key(:sign)
      end

      it "返回 msg 提示消息" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: package.id, payment_method: "wechat" },
             as: :json

        expect(json_response[:response][:msg]).to include("支付")
      end

      it "生成订单记录和会员记录" do
        expect do
          post "/api/memberships/create_order",
               params: { uuid: user.uuid, package_id: package.id, payment_method: "wechat" },
               as: :json
        end.to change(Order, :count).by(1)
                                    .and change(Membership, :count).by(1)
      end

      it "会员记录使用套餐的价格和有效天数" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: package.id, payment_method: "wechat" },
             as: :json

        order = Order.find_by(order_no: json_response[:response][:data][:order][:order_no])
        expect(order.membership.price.to_f).to eq(19.9)
        expect(order.membership.end_date).to eq(Date.current + 30)
      end

      it "无效的 package_id 返回错误" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: 999, payment_method: "wechat" },
             as: :json

        expect(response).to have_http_status(200)
        expect(json_response[:response][:code]).not_to eq(0)
      end

      it "重复点击时返回已有待支付订单而非创建新订单" do
        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: package.id, payment_method: "wechat" },
             as: :json

        first_order_no = json_response[:response][:data][:order][:order_no]

        post "/api/memberships/create_order",
             params: { uuid: user.uuid, package_id: package.id, payment_method: "wechat" },
             as: :json

        expect(response).to have_http_status(200).or have_http_status(201)
        expect(json_response[:response][:code]).to eq(0)
        expect(json_response[:response][:data][:order][:order_no]).to eq(first_order_no)
        expect(json_response[:response][:msg]).to include("待支付")
      end
    end

    context "未登录" do
      it "返回未授权" do
        post "/api/memberships/create_order",
             params: { uuid: "nonexistent-uuid", package_id: package.id, payment_method: "wechat" },
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
      ENV["ALIPAY_RESPONSE_PUBLIC_KEY"] = private_key.public_key.to_pem

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
      private_key = OpenSSL::PKey::RSA.generate(2048)
      ENV["ALIPAY_RESPONSE_PUBLIC_KEY"] = private_key.public_key.to_pem

      post "/api/memberships/alipay_callback",
           params: { out_trade_no: "test", trade_status: "TRADE_SUCCESS", sign: "bad", sign_type: "RSA2" }

      expect(response.body).to include("failure")
    end
  end
end
