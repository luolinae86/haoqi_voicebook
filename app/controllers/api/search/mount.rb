# frozen_string_literal: true

# 搜索模块挂载
module Api
  module Search
    class Mount < Grape::API
      mount Api::Search::SearchApi
    end
  end
end
