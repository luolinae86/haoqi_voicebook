# frozen_string_literal: true

# 头像模块挂载
module Api
  module HeadImgs
    class Mount < Grape::API
      mount Api::HeadImgs::HeadImgApi
    end
  end
end
