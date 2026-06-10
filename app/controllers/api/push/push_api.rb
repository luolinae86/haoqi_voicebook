# frozen_string_literal: true

# 推送 API
# 提供消息推送接口，同时发送透传消息 + 离线通知
module Api
  module Push
    class PushApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :push do
        # ==================== 按年级推送 ====================
        desc '按年级推送消息（推送给指定年级的所有用户）'
        params do
          requires :grade_ids, type: [Integer], desc: '年级ID列表'
          requires :title, type: String, desc: '消息标题'
          requires :body, type: String, desc: '消息内容'
          optional :type, type: String, desc: '消息类型'
          optional :content, type: Hash, desc: '消息内容详情（JSON对象）'
        end
        post :send do
          auth_user

          grade_ids = params[:grade_ids]
          raise ArgumentError, 'grade_ids 不能为空' if grade_ids.blank?

          payload = {
            title: params[:title],
            body: params[:body]
          }
          payload[:type] = params[:type] if params[:type].present?
          payload[:content] = params[:content] if params[:content].present?

          # 查找指定年级的所有用户的有效 push_cid
          cid_list = Device.joins(:app_user)
                           .where(app_users: { grade_id: grade_ids })
                           .where.not(push_cid: [nil, ''])
                           .pluck(:push_cid)
                           .uniq

          raise ArgumentError, '未找到推送CID，指定年级下没有有效设备' if cid_list.empty?

          service = GetuiService.new

          if cid_list.size == 1
            result = service.push_to_single(cid_list.first, params[:title], params[:body], payload: payload)
            push_result = [{ cid: cid_list.first, result: result }]
          else
            results = service.push_to_batch(cid_list, params[:title], params[:body], payload: payload)
            push_result = cid_list.map.with_index do |cid, idx|
              { cid: cid, result: results[idx] }
            end
          end

          present response: success_response(
            msg: "推送到 #{push_result.size} 个设备成功",
            data: {
              devices: push_result,
              grade_ids: grade_ids,
              title: params[:title],
              body: params[:body],
              payload: payload
            }
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
