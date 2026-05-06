# frozen_string_literal: true

# 用户模块挂载
module Api
  module V1
    module AppUsers
      class Mount < Grape::API
        mount Api::V1::AppUsers::Auth
      end
    end
  end
end
