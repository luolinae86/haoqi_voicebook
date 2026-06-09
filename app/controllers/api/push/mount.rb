# frozen_string_literal: true

# 推送模块挂载
module Api
  module Push
    class Mount < Grape::API
      mount Api::Push::PushApi
    end
  end
end
