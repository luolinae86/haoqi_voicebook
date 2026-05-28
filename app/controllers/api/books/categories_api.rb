# frozen_string_literal: true

# 图书分类接口
module Api
  module Books
    class CategoriesApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :categories do
        desc '获取图书分类列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
          optional :level, type: Integer, desc: '分类层级'
        end
        get :list do
          auth_user

          scope = Category.sorted
          scope = scope.by_level(params[:level]) if params[:level].present?

          present response: success_response(
            categories: serialize_collection(scope, Entities::Category)
          )
        end
      end
    end
  end
end
