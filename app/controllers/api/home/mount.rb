# frozen_string_literal: true

# 首页模块挂载
module Api
  module Home
    class Mount < Grape::API
      mount Api::Home::HomeApi
    end
  end
end
