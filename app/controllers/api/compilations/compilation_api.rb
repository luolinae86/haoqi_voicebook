# frozen_string_literal: true

module Api
  module Compilations
    class CompilationApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Compilations::CompilationHelpers

      namespace :compilations do
        desc '获取合集详情及其关联的图书和资源（需 uuid 鉴权）'
        params do
          requires :id, type: Integer, desc: '合集ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get ':id' do
          auth_user

          compilation = Compilation.find_by(id: params[:id])
          error_pop_resp('合集不存在') unless compilation

          present response: success_response(compilation: compilation_detail(compilation))
        end
      end
    end
  end
end
