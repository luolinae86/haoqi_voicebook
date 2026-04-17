# frozen_string_literal: true

# 首页模块挂载
module Api
  module V1
    module Home
      class Mount < Grape::API
        mount Api::V1::Home::HomeApi
      end
    end
  end
end
