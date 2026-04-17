# frozen_string_literal: true

# 有声模块挂载
module Api
  module V1
    module Audio
      class Mount < Grape::API
        mount Api::V1::Audio::AudioApi
      end
    end
  end
end
