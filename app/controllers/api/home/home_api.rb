# frozen_string_literal: true

module Api
  module Home
    class HomeApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Home::HomeHelpers

      namespace :home do
        desc "获取首页推荐内容（根据用户年级）"
        params do
          requires :uuid, type: String, desc: "用户uuid"
        end
        get do
          auth_user

          recommends = if current_user.grade_id.present?
                         home_recommends_for_grade(current_user.grade_id)
                       else
                         []
                       end

          present response: success_response(recommends: recommends)
        end
      end
    end
  end
end
