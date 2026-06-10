# frozen_string_literal: true

# 推送 API
# 提供消息推送接口，同时发送透传消息 + 离线通知
module Api
  module Push
    class PushApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :push do
        # ==================== 推送消息 ====================
        desc '推送消息（同时推送给用户所有登录设备）'
        params do
          requires :uuid, type: String, desc: '用户UUID'
          optional :cid, type: String, desc: '指定单个CID（不传则推送给用户所有设备）'
          requires :title, type: String, desc: '消息标题'
          requires :body, type: String, desc: '消息内容'
          optional :type, type: String, desc: '消息类型'
          optional :content, type: Hash, desc: '消息内容详情（JSON对象）'
        end
        post :send do
          auth_user

          payload = {
            title: params[:title],
            body: params[:body]
          }
          payload[:type] = params[:type] if params[:type].present?
          payload[:content] = params[:content] if params[:content].present?

          # 如果指定了cid，只推送到该cid
          if params[:cid].present?
            cid = params[:cid]
            raise ArgumentError, '未找到推送CID' unless cid.present?

            service = GetuiService.new
            result = service.push_to_single(cid, params[:title], params[:body], payload: payload)

            present response: success_response(
              msg: '推送到 1 个设备成功',
              data: {
                devices: [{ cid: cid, result: result }],
                title: params[:title],
                body: params[:body],
                payload: payload
              }
            )
          else
            # 获取用户所有设备的push_cid
            cid_list = current_user.devices.where.not(push_cid: [nil, '']).pluck(:push_cid).uniq

            raise ArgumentError, '未找到推送CID，请先更新个推CID' if cid_list.empty?

            service = GetuiService.new

            if cid_list.size == 1
              # 单设备，用单推
              result = service.push_to_single(cid_list.first, params[:title], params[:body], payload: payload)
              devices_result = [{ cid: cid_list.first, result: result }]
            else
              # 多设备，批量推
              results = service.push_to_batch(cid_list, params[:title], params[:body], payload: payload)
              devices_result = cid_list.map.with_index do |cid, idx|
                { cid: cid, result: results[idx] }
              end
            end

            present response: success_response(
              msg: "推送到 #{devices_result.size} 个设备成功",
              data: {
                devices: devices_result,
                title: params[:title],
                body: params[:body],
                payload: payload
              }
            )
          end
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
