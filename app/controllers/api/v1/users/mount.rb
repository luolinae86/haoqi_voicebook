# frozen_string_literal: true

# 用户模块挂载
module Api
  module V1
    module Users
      class Mount < Grape::API
        mount Api::V1::Users::Auth
        mount Api::V1::Users::Profile
      end
    end
  end
end
