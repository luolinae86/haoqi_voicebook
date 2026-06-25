# frozen_string_literal: true

module Api
  module Home
    class HomeApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Home::HomeHelpers

      namespace :home do
        desc '获取首页推荐列表（仅 recommends 层级）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get :recommends do
          auth_user

          recommends = if current_user.grade_id.present?
                         Recommend.by_grade(current_user.grade_id).published
                       else
                         []
                       end

          present response: success_response(recommends: serialize_collection(recommends, Entities::Recommend))
        end

        desc '获取指定推荐的详细内容（含 content_groups 和 contents）'
        params do
          requires :recommend_id, type: Integer, desc: '推荐ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get 'recommends/by_recommend_id' do
          auth_user

          recommend = Recommend.find_by(id: params[:recommend_id], grade_id: current_user.grade_id)
          content_groups = recommend ? recommend.content_groups.includes(:contents).map { |cg| serialize_content_group(cg) } : []

          present response: success_response(content_groups: content_groups)
        end
      end
    end
  end
end