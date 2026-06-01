# frozen_string_literal: true

# 会员购买接口
# 提供会员套餐列表、创建订单、支付回调等功能
module Api
  module Memberships
    class MembershipApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :memberships do
        # ==================== 获取会员套餐列表 ====================
        desc '获取会员套餐列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :plans do
          auth_user

          packages = Package.ordered_by_price

          present response: success_response(packages: serialize_collection(packages, Entities::Package))
        end

        # ==================== 创建会员订单 ====================
        desc '创建会员购买订单，返回支付参数'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :package_id, type: Integer, desc: '套餐ID'
          requires :payment_method, type: String, desc: '支付方式：alipay/wechat', values: %w[alipay wechat]
        end
        post :create_order do
          auth_user

          package = Package.find_by(id: params[:package_id])
          raise ArgumentError, '无效的套餐' unless package

          # 防止重复点击创建多个待支付订单
          pending_membership = Membership.find_by(app_user: current_user, status: :pending)
          if pending_membership && pending_membership.orders.pending.exists?
            order = pending_membership.orders.pending.first
            present response: success_response(
              order: Entities::Order.represent(order).as_json,
              msg: '已有待支付订单，请完成支付'
            )
            next
          end

          # 创建待支付会员记录
          membership = Membership.create!(
            app_user: current_user,
            plan_type: :monthly,
            price: package.price,
            original_price: package.origin_price,
            start_date: Date.current,
            end_date: Date.current + package.effective_days,
            status: :pending
          )

          # 创建订单
          order = Order.create!(
            app_user: current_user,
            membership: membership,
            amount: package.price,
            payment_method: params[:payment_method]
          )

          # 生成支付参数
          subject = "#{package.name} - #{package.price}元"
          payment_params = case params[:payment_method]
                           when 'alipay'
                             AlipayPaymentService.new.create_order(
                               order_no: order.order_no,
                               amount: package.price,
                               subject: subject
                             )
                           when 'wechat'
                             WechatPaymentService.new.create_prepay(
                               order_no: order.order_no,
                               amount: package.price,
                               subject: subject
                             )
                           end

          present response: success_response(
            order: Entities::Order.represent(order).as_json,
            payment_params: payment_params,
            msg: '订单创建成功，请完成支付'
          )
        end

        # ==================== 查询订阅记录 ====================
        desc '查询当前用户的会员订阅记录'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :subscriptions do
          auth_user

          orders = Order.paid_with_membership(current_user)

          items = orders.map do |order|
            membership = order.membership
            end_date = membership.end_date
            days_left = [0, (end_date - Date.current).to_i].max
            expired = end_date < Date.current

            {
              order_no: order.order_no,
              plan_label: membership.plan_label,
              price: order.amount,
              paid_at: order.paid_at&.strftime('%Y-%m-%d %H:%M:%S') || '',
              days_left: days_left,
              expired: expired
            }
          end

          present response: success_response(items: items)
        end

        # ==================== 支付宝异步回调 ====================
        desc '支付宝支付异步通知回调（无需鉴权）'
        post :alipay_callback do
          callback_params = params.except(:route_info)
          alipay_service = AlipayPaymentService.new

          if alipay_service.verify_callback?(callback_params)
            trade_status = callback_params['trade_status']

            if %w[TRADE_SUCCESS TRADE_FINISHED].include?(trade_status)
              order_no = callback_params['out_trade_no']
              PaymentCallbackWorker.perform_async({
                                                    'order_no' => order_no,
                                                    'payment_method' => 'alipay',
                                                    'result' => callback_params.to_h
                                                  })
            end

            # 返回 success 给支付宝
            content_type 'text/plain'
            'success'
          else
            Rails.logger.warn("[AlipayCallback] Signature verification failed for order: #{callback_params['out_trade_no']}")
            content_type 'text/plain'
            'failure'
          end
        end

        # ==================== 微信异步回调 ====================
        desc '微信支付异步通知回调（无需鉴权）'
        post :wechat_callback do
          # 读取回调 body（优先从 rack.input 读取原始 body，兼容 Grape 解析后）
          callback_body = begin
            raw = env['rack.input']
            if raw.respond_to?(:rewind)
              raw.rewind
              content = raw.read
              raw.rewind
              content
            else
              raw.gets(nil).to_s
            end
          rescue
            ''
          end

          # 如果 raw body 为空（Grape 已消费），从 params 获取
          if callback_body.blank?
            callback_body = params.except(:route_info, :version, :format).to_json
          end

          callback_headers = {
            'Wechatpay-Timestamp' => headers['Wechatpay-Timestamp'],
            'Wechatpay-Nonce' => headers['Wechatpay-Nonce'],
            'Wechatpay-Signature' => headers['Wechatpay-Signature'],
            'Wechatpay-Serial' => headers['Wechatpay-Serial']
          }

          wechat_service = WechatPaymentService.new

          if wechat_service.verify_callback?(callback_headers, callback_body)
            begin
              result = JSON.parse(callback_body)
              order_no = result['out_trade_no']
              trade_state = result['trade_state']

              if trade_state == 'SUCCESS'
                PaymentCallbackWorker.perform_async({
                                                      'order_no' => order_no,
                                                      'payment_method' => 'wechat',
                                                      'result' => result
                                                    })
              end

              { code: 'SUCCESS', msg: '成功' }
            rescue JSON::ParserError
              { code: 'FAIL', msg: '解析失败' }
            end
          else
            Rails.logger.warn('[WechatCallback] Signature verification failed')
            { code: 'FAIL', msg: '签名验证失败' }
          end
        end
      end
    end
  end
end
