# frozen_string_literal: true

module Api
  module Grades
    class GradeApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :grades do
        desc "获取所有年级列表"
        get do
          grades = Grade.order(:id)
          present response: success_response(grades: grades.map { |g| Entities::Grade.represent(g).as_json })
        end
      end
    end
  end
end
