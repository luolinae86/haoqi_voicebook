# frozen_string_literal: true

# 家长管控模块挂载
module Api
  module V1
    module Parental
      class Mount < Grape::API
        mount Api::V1::Parental::ParentalApi
      end
    end
  end
end
