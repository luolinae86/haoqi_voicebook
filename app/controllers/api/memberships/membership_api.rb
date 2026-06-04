# frozen_string_literal: true

# 会员购买接口
# 提供会员套餐列表、创建订单、支付回调等功能
module Api
  module Memberships
    class MembershipApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :memberships do
        # ==================== 支付宝异步回调（单独 namespace，提前捕获 raw body） ====================
        # Grape 会消费 rack.input 解析 params，但支付宝回调签名基于原始 URL-encoded body
        # 使用 separate namespace + before 块在 Grape 解析前读取原始 body
        namespace :alipay_callback do
          before do
            raw = env['rack.input']
            if raw.respond_to?(:rewind)
              raw.rewind
              @alipay_raw_body = raw.read
              raw.rewind
            else
              @alipay_raw_body = raw.to_s
            end
          rescue StandardError
            @alipay_raw_body = ''
          end

          route :post do
            callback_params = params.except(:route_info)
            alipay_service = AlipayPaymentService.new

            if alipay_service.verify_callback_with_raw_body?(callback_params, @alipay_raw_body)
              trade_status = callback_params['trade_status']

              if %w[TRADE_SUCCESS TRADE_FINISHED].include?(trade_status)
                order_no = callback_params['out_trade_no']
                PaymentCallbackWorker.perform_async({
                                                      'order_no' => order_no,
                                                      'payment_method' => 'alipay',
                                                      'result' => callback_params.to_h
                                                    })
              end

              content_type 'text/plain'
              'success'
            else
              Rails.logger.warn("[AlipayCallback] Signature verification failed for order: #{callback_params['out_trade_no']}, raw_body_len=#{@alipay_raw_body.length}, raw_body=#{@alipay_raw_body[0..200]}")
              content_type 'text/plain'
              'failure'
            end
          end
        end

        # 其他接口
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

            {
              order_no: order.order_no,
              plan_label: membership.plan_label,
              price: order.amount,
              paid_at: order.paid_at&.strftime('%Y-%m-%d %H:%M:%S') || '',
              duration_days: membership.duration_days
            }
          end

          present response: success_response(items: items)
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
          rescue StandardError
            ''
          end

          # 如果 raw body 为空（Grape 已消费），从 params 获取
          callback_body = params.except(:route_info, :version, :format).to_json if callback_body.blank?

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
