# frozen_string_literal: true

# 用户模块挂载
module Api
  module AppUsers
    class Mount < Grape::API
      mount Api::AppUsers::ApiUserApi
    end
  end
end
