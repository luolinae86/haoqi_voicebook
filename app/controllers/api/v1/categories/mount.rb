# frozen_string_literal: true

# 分类模块挂载
module Api
  module V1
    module Categories
      class Mount < Grape::API
        mount Api::V1::Categories::CategoryApi
      end
    end
  end
end
