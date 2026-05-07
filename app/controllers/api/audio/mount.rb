# frozen_string_literal: true

# 有声模块挂载
module Api
  module Audio
    class Mount < Grape::API
      mount Api::Audio::AudioApi
    end
  end
end
