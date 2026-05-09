# frozen_string_literal: true

# 会员购买接口
# 提供会员套餐列表、创建订单、支付回调等功能
module Api
  module Memberships
    class MembershipApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      def self.calculate_end_date(plan_type)
        case plan_type
        when "monthly"   then 1.month.from_now.to_date
        when "quarterly" then 3.months.from_now.to_date
        when "annual"    then 1.year.from_now.to_date
        end
      end

      namespace :memberships do
        # ==================== 获取会员套餐列表 ====================
        desc "获取会员套餐列表（年度/季度/月度）"
        params do
          requires :device_id, type: String, desc: "设备ID"
        end
        get :plans do
          auth_user

          plans = Membership::PLAN_PRICES.map do |plan_type, info|
            {
              plan_type: plan_type.to_s,
              plan_label: Membership::PLAN_LABELS[plan_type],
              price: info[:price],
              original_price: info[:original_price]
            }
          end

          present response: success_response(plans: plans)
        end

        # ==================== 创建会员订单 ====================
        desc "创建会员购买订单，返回支付参数"
        params do
          requires :device_id, type: String, desc: "设备ID"
          requires :plan_type, type: String, desc: "套餐类型：monthly/quarterly/annual", values: %w[monthly quarterly annual]
          requires :payment_method, type: String, desc: "支付方式：alipay/wechat", values: %w[alipay wechat]
        end
        post :create_order do
          auth_user

          plan_info = Membership.plan_info(params[:plan_type])
          raise ArgumentError, "无效的套餐类型" unless plan_info

          # 创建待支付会员记录
          membership = Membership.create!(
            app_user: current_user,
            plan_type: params[:plan_type],
            price: plan_info[:price],
            original_price: plan_info[:original_price],
            start_date: Date.current,
            end_date: MembershipApi.calculate_end_date(params[:plan_type]),
            status: :pending
          )

          # 创建订单
          order = Order.create!(
            app_user: current_user,
            membership: membership,
            amount: plan_info[:price],
            payment_method: params[:payment_method]
          )

          # 生成支付参数
          subject = "#{Membership::PLAN_LABELS[params[:plan_type].to_sym]} - #{plan_info[:price]}元"
          payment_params = case params[:payment_method]
                           when "alipay"
                             AlipayPaymentService.new.create_order(
                               order_no: order.order_no,
                               amount: plan_info[:price],
                               subject: subject
                             )
                           when "wechat"
                             WechatPaymentService.new.create_prepay(
                               order_no: order.order_no,
                               amount: plan_info[:price],
                               subject: subject
                             )
                           end

          present response: success_response(
                  order: Entities::Order.represent(order).as_json,
                  payment_params: payment_params,
                  msg: "订单创建成功，请完成支付"
                )
        end

        # ==================== 支付宝异步回调 ====================
        desc "支付宝支付异步通知回调（无需鉴权）"
        post :alipay_callback do
          callback_params = params.except(:route_info)
          alipay_service = AlipayPaymentService.new

          if alipay_service.verify_callback?(callback_params)
            trade_status = callback_params["trade_status"]

            if %w[TRADE_SUCCESS TRADE_FINISHED].include?(trade_status)
              order_no = callback_params["out_trade_no"]
              PaymentCallbackWorker.perform_async({
                                                    "order_no" => order_no,
                                                    "payment_method" => "alipay",
                                                    "result" => callback_params.to_h
                                                  })
            end

            # 返回 success 给支付宝
            content_type "text/plain"
            "success"
          else
            Rails.logger.warn("[AlipayCallback] Signature verification failed for order: #{callback_params['out_trade_no']}")
            content_type "text/plain"
            "failure"
          end
        end

        # ==================== 微信异步回调 ====================
        desc "微信支付异步通知回调（无需鉴权）"
        post :wechat_callback do
          callback_body = env["rack.input"].gets(nil)&.force_encoding("utf-8") || ""
          callback_headers = {
            "Wechatpay-Timestamp" => headers["Wechatpay-Timestamp"],
            "Wechatpay-Nonce" => headers["Wechatpay-Nonce"],
            "Wechatpay-Signature" => headers["Wechatpay-Signature"],
            "Wechatpay-Serial" => headers["Wechatpay-Serial"]
          }

          wechat_service = WechatPaymentService.new

          if wechat_service.verify_callback?(callback_headers, callback_body)
            begin
              result = JSON.parse(callback_body)
              order_no = result["out_trade_no"]
              trade_state = result["trade_state"]

              if trade_state == "SUCCESS"
                PaymentCallbackWorker.perform_async({
                                                      "order_no" => order_no,
                                                      "payment_method" => "wechat",
                                                      "result" => result
                                                    })
              end

              { code: "SUCCESS", msg: "成功" }
            rescue JSON::ParserError
              { code: "FAIL", msg: "解析失败" }
            end
          else
            Rails.logger.warn("[WechatCallback] Signature verification failed")
            { code: "FAIL", msg: "签名验证失败" }
          end
        end
      end
    end
  end
end
