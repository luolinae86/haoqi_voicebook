# frozen_string_literal: true

# 图书模块挂载
module Api
  module V1
    module Books
      class Mount < Grape::API
        mount Api::V1::Books::BookApi
      end
    end
  end
end
