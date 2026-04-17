# frozen_string_literal: true

# 会员与订单接口
# 提供 VIP 会员套餐查看、购买、订单管理等功能
module Api
  module V1
    module Memberships
      class MembershipApi < Grape::API
        helpers Api::Helpers::CommonHelpers

        namespace :memberships do
          # ==================== 会员套餐列表 ====================
          desc "获取会员套餐信息"
          get :plans do
            success_response([
              { plan_type: "annual", name: "年度会员", price: 302, original_price: 348, discount: "限时8折" },
              { plan_type: "quarterly", name: "季度会员", price: 78, original_price: 98, discount: "限时8折" },
              { plan_type: "monthly", name: "月度会员", price: 36, original_price: 46, discount: "限时8折" }
            ])
          end

          # 以下接口需要登录
          before { authenticate_user! }

          # ==================== 购买会员 ====================
          desc "购买会员（创建订单）"
          params do
            requires :plan_type, type: String, desc: "套餐类型：monthly/quarterly/annual"
            requires :payment_method, type: String, desc: "支付方式：alipay/wechat"
          end
          post :purchase do
            # 定义套餐价格
            plan_config = {
              "monthly" => { price: 36, original: 46, days: 30 },
              "quarterly" => { price: 78, original: 98, days: 90 },
              "annual" => { price: 302, original: 348, days: 365 }
            }

            config = plan_config[params[:plan_type]]
            error!(err_response(code: 1002, message: "无效的套餐类型"), 400) unless config

            # 创建会员记录
            membership = current_user.memberships.create!(
              plan_type: params[:plan_type],
              price: config[:price],
              original_price: config[:original],
              start_date: Date.current,
              end_date: Date.current + config[:days].days,
              status: :pending
            )

            # 创建订单
            order = current_user.orders.create!(
              amount: config[:price],
              payment_method: params[:payment_method],
              membership: membership,
              status: :pending
            )

            success_response({
              order_no: order.order_no,
              amount: order.amount.to_f,
              payment_method: order.payment_method,
              membership_id: membership.id
            }, message: "订单创建成功，请完成支付")
          end

          # ==================== 支付回调（模拟） ====================
          desc "支付回调（模拟支付成功）"
          params do
            requires :order_no, type: String, desc: "订单号"
          end
          post :payment_callback do
            order = Order.find_by!(order_no: params[:order_no])

            # 标记订单为已支付
            order.mark_paid!

            # 激活会员
            membership = order.membership
            membership.update!(status: :active)

            # 更新用户 VIP 状态
            current_user.update!(
              is_vip: true,
              vip_expires_at: membership.end_date.end_of_day
            )

            success_response(nil, message: "支付成功，VIP 已开通")
          end

          # ==================== 我的会员信息 ====================
          desc "获取我的会员信息"
          get :my do
            active_membership = current_user.memberships.active_memberships.order(end_date: :desc).first

            success_response({
              is_vip: current_user.vip_active?,
              vip_expires_at: current_user.vip_expires_at&.strftime("%Y-%m-%d"),
              current_plan: active_membership ? {
                plan_type: active_membership.plan_type,
                start_date: active_membership.start_date.strftime("%Y-%m-%d"),
                end_date: active_membership.end_date.strftime("%Y-%m-%d"),
                remaining_days: (active_membership.end_date - Date.current).to_i
              } : nil
            })
          end
        end
      end
    end
  end
end
