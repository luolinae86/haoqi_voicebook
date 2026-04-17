# frozen_string_literal: true

# 搜索模块挂载
module Api
  module V1
    module Search
      class Mount < Grape::API
        mount Api::V1::Search::SearchApi
      end
    end
  end
end
