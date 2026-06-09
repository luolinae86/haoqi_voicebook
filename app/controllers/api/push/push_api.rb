# frozen_string_literal: true

# 推送 API
# 提供消息推送接口，同时发送透传消息 + 离线通知
module Api
  module Push
    class PushApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :push do
        # ==================== 推送消息 ====================
        desc '推送消息（同时发送透传+离线通知）'
        params do
          requires :uuid, type: String, desc: '用户UUID'
          optional :cid, type: String, desc: '指定CID（可选，不传则查用户最新设备）'
          requires :title, type: String, desc: '消息标题'
          requires :body, type: String, desc: '消息内容'
          optional :type, type: String, desc: '消息类型'
          optional :content, type: Hash, desc: '消息内容详情（JSON对象）'
        end
        post :send do
          auth_user

          cid = params[:cid]
          unless cid
            device = current_user.devices.order(created_at: :desc).first
            cid = device&.push_cid
          end

          raise ArgumentError, '未找到推送CID，请先更新个推CID' unless cid.present?

          payload = {
            title: params[:title],
            body: params[:body]
          }
          payload[:type] = params[:type] if params[:type].present?
          payload[:content] = params[:content] if params[:content].present?

          service = GetuiService.new
          result = service.push_to_single(cid, params[:title], params[:body], payload: payload)

          present response: success_response(
            msg: '推送成功',
            data: { cid: cid, title: params[:title], body: params[:body], payload: payload, result: result }
          )
        rescue GetuiService::PushError => e
          error!({ code: 1, msg: "推送失败: #{e.message}" }, 400)
        rescue ArgumentError => e
          error!({ code: 1, msg: e.message }, 400)
        end

        # ==================== 测试推送（无需鉴权） ====================
        desc '测试推送（开发调试用，无需鉴权）'
        params do
          requires :cid, type: String, desc: '客户端CID'
          requires :title, type: String, desc: '消息标题'
          requires :body, type: String, desc: '消息内容'
          optional :type, type: String, desc: '消息类型'
          optional :content, type: Hash, desc: '消息内容详情（JSON对象）'
        end
        post :test do
          payload = {
            title: params[:title],
            body: params[:body]
          }
          payload[:type] = params[:type] if params[:type].present?
          payload[:content] = params[:content] if params[:content].present?

          service = GetuiService.new
          result = service.push_to_single(params[:cid], params[:title], params[:body], payload: payload)

          present response: success_response(
            msg: '推送成功',
            data: { cid: params[:cid], title: params[:title], body: params[:body], payload: payload, result: result }
          )
        rescue GetuiService::PushError => e
          error!({ code: 1, msg: "推送失败: #{e.message}" }, 400)
        rescue ArgumentError => e
          error!({ code: 1, msg: e.message }, 400)
        end
      end
    end
  end
end
