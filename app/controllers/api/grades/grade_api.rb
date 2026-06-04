# frozen_string_literal: true

module Api
  module Grades
    class GradeApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :grades do
        before do
          auth_user
        end

        desc '获取所有年级列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get do
          grades = Grade.by_group_order
          present response: success_response(grades: grades.map { |g| Entities::Grade.represent(g).as_json })
        end
      end
    end
  end
end
