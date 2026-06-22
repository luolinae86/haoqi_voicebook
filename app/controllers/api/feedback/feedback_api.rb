# frozen_string_literal: true

module Api
  module Feedback
    class FeedbackApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :feedback do
        before do
          auth_user
        end

        rescue_from ActiveRecord::RecordInvalid do |e|
          error_pop_resp(e.record.errors.full_messages.join(', '))
        end

        # ==================== 提交反馈 ====================
        desc '提交用户意见反馈'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          requires :type, type: String, values: %w[bug content_suggestion other], desc: '反馈类型'
          requires :content, type: String, desc: '反馈内容（最多500字）'
          optional :images, type: Array, desc: '图片URL列表（最多3张）'
        end
        post do
          feedback = current_user.feedbacks.create!(
            feedback_type: params[:type],
            content: params[:content],
            images: params[:images].to_json
          )

          present response: success_response(
            feedback: Entities::Feedback.represent(feedback).as_json,
            msg: '反馈提交成功'
          )
        end

        # ==================== 反馈列表 ====================
        desc '获取当前用户的反馈列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :page, type: Integer, default: 1, desc: '页码'
          optional :per_page, type: Integer, default: 20, desc: '每页数量'
        end
        get :list do
          items = current_user.feedbacks
                             .order(created_at: :desc)
                             .page(params[:page]).per(params[:per_page])

          present response: success_response(
            feedbacks: serialize_collection(items, Entities::Feedback),
            pagination: pagination_info(items)
          )
        end
      end
    end
  end
end
