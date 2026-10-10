# frozen_string_literal: true

# 会员购买接口
# 提供会员套餐列表、创建订单、支付回调等功能
module Api
  module Memberships
    class MembershipApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      helpers do
        # 生成微信支付二维码图片并上传到 OSS（使用签名 URL，适配私有 bucket）
        def generate_qr_code(code_url, order_no)
          require 'rqrcode'

          qr = RQRCode::QRCode.new(code_url)
          png = qr.as_png(size: 300, border_modules: 4, module_px_size: 6)

          oss_service = AliyunOssService.new
          object_key = "qr_codes/wechat_pay_#{order_no}.png"

          oss_service.upload_data(
            data: png.to_s,
            object_key: object_key,
            content_type: 'image/png'
          )

          # 返回签名 URL（私有 bucket 需要签名才能访问）
          oss_service.generate_signed_url(object_key, expires: 86400)
        rescue StandardError => e
          Rails.logger.error("[MembershipApi] Failed to generate QR code: #{e.message}")
          nil
        end
      end

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

          packages = Package.sorted

          present response: success_response(packages: serialize_collection(packages, Entities::Package))
        end

        # ==================== 创建会员订单 ====================
        desc '创建会员购买订单，返回支付参数'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :package_id, type: Integer, desc: '套餐ID'
          requires :payment_method, type: String, desc: '支付方式：alipay/wechat', values: %w[alipay wechat]
          optional :pay_scene, type: String, desc: '支付场景：app(默认)/native(扫码)', values: %w[app native], default: 'app'
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
            package: package,
            amount: package.price,
            payment_method: params[:payment_method],
            channel: current_user.channel
          )

          # 生成支付参数
          subject = "#{package.name} - #{package.price}元"
          pay_scene = params[:pay_scene] || 'app'
          payment_params = case params[:payment_method]
                           when 'alipay'
                             if pay_scene == 'native'
                               # 当面付扫码支付
                               AlipayPaymentService.new.create_native_order(
                                 order_no: order.order_no,
                                 amount: package.price,
                                 subject: subject
                               )
                             else
                               # APP 支付
                               AlipayPaymentService.new.create_order(
                                 order_no: order.order_no,
                                 amount: package.price,
                                 subject: subject
                               )
                             end
                           when 'wechat'
                             if pay_scene == 'native'
                               # Native 支付（扫码支付）
                               WechatPaymentService.new.create_native_prepay(
                                 order_no: order.order_no,
                                 amount: package.price,
                                 subject: subject
                               )
                             else
                               # APP 支付
                               WechatPaymentService.new.create_prepay(
                                 order_no: order.order_no,
                                 amount: package.price,
                                 subject: subject
                               )
                             end
                           end

          response_data = {
            order: Entities::Order.represent(order).as_json,
            payment_params: payment_params,
            msg: '订单创建成功，请完成支付'
          }

          # 如果是扫码支付，生成二维码图片
          if pay_scene == 'native'
            qr_url = if params[:payment_method] == 'wechat'
                       payment_params[:code_url]
                     else
                       payment_params[:qr_code]
                     end

            if qr_url
              qr_code_url = generate_qr_code(qr_url, order.order_no)
              response_data[:qr_code_url] = qr_code_url if qr_code_url
            end
          end

          present response: success_response(response_data)
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

        # ==================== 查询订单支付状态 ====================
        desc '查询订单支付状态（用于扫码支付轮询）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :order_no, type: String, desc: '订单号'
        end
        get :check_payment_status do
          auth_user

          order = Order.find_by(order_no: params[:order_no], app_user_id: current_user.id)
          error_pop_resp('订单不存在') unless order

          present response: success_response(
            order_no: order.order_no,
            status: order.status,
            paid_at: order.paid_at&.strftime('%Y-%m-%d %H:%M:%S')
          )
        end

        # ==================== 微信异步回调 ====================
        desc '微信支付异步通知回调（无需鉴权）'
        post :wechat_callback do
          Rails.logger.info("[WechatCallback] === Callback received ===")
          Rails.logger.info("[WechatCallback] Serial: #{headers['Wechatpay-Serial']}, Timestamp present: #{headers['Wechatpay-Timestamp'].present?}")

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
          rescue StandardError => e
            Rails.logger.error("[WechatCallback] Error reading body: #{e.class}: #{e.message}")
            ''
          end

          Rails.logger.info("[WechatCallback] Body length: #{callback_body.length}, blank? #{callback_body.blank?}")

          # 如果 raw body 为空（Grape 已消费），从 params 获取
          callback_body = params.except(:route_info, :version, :format).to_json if callback_body.blank?

          callback_headers = {
            'Wechatpay-Timestamp' => headers['Wechatpay-Timestamp'],
            'Wechatpay-Nonce' => headers['Wechatpay-Nonce'],
            'Wechatpay-Signature' => headers['Wechatpay-Signature'],
            'Wechatpay-Serial' => headers['Wechatpay-Serial']
          }

          Rails.logger.info("[WechatCallback] About to verify, headers: #{callback_headers.transform_values { |v| v&.length }}")
          wechat_service = WechatPaymentService.new

          if wechat_service.verify_callback?(callback_headers, callback_body)
            Rails.logger.info("[WechatCallback] Signature verification PASSED")
            begin
              # 微信回调 body 是加密的，需要先解密
              callback_data = JSON.parse(callback_body)
              resource = callback_data['resource']

              if resource && resource['ciphertext']
                # 解密回调数据
                decrypted = wechat_service.decrypt_callback(
                  ciphertext: resource['ciphertext'],
                  associated_data: resource['associated_data'] || '',
                  nonce: resource['nonce']
                )

                if decrypted
                  Rails.logger.info("[WechatCallback] Decrypted callback: #{decrypted.to_json}")
                  order_no = decrypted['out_trade_no']
                  trade_state = decrypted['trade_state']

                  if trade_state == 'SUCCESS'
                    PaymentCallbackWorker.perform_async({
                                                          'order_no' => order_no,
                                                          'payment_method' => 'wechat',
                                                          'result' => decrypted
                                                        })
                  end
                else
                  Rails.logger.error("[WechatCallback] Failed to decrypt callback")
                end
              else
                # 非加密格式（兼容旧版本）
                order_no = callback_data['out_trade_no']
                trade_state = callback_data['trade_state']

                if trade_state == 'SUCCESS'
                  PaymentCallbackWorker.perform_async({
                                                        'order_no' => order_no,
                                                        'payment_method' => 'wechat',
                                                        'result' => callback_data
                                                      })
                end
              end

              { code: 'SUCCESS', msg: '成功' }
            rescue JSON::ParserError => e
              Rails.logger.error("[WechatCallback] JSON parse error: #{e.message}")
              { code: 'FAIL', msg: '解析失败' }
            rescue StandardError => e
              Rails.logger.error("[WechatCallback] Error: #{e.class}: #{e.message}")
              { code: 'FAIL', msg: '处理失败' }
            end
          else
            Rails.logger.warn('[WechatCallback] Signature verification FAILED')
            { code: 'FAIL', msg: '签名验证失败' }
          end
        end
      end
    end
  end
end
