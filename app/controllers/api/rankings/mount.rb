# frozen_string_literal: true

# 排行榜模块挂载
module Api
  module Rankings
    class Mount < Grape::API
      mount Api::Rankings::RankingApi
    end
  end
end
