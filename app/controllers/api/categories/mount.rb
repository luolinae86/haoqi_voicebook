# frozen_string_literal: true

# 分类模块挂载
module Api
  module Categories
    class Mount < Grape::API
      mount Api::Categories::CategoryApi
    end
  end
end
