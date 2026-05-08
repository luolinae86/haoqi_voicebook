# frozen_string_literal: true

# 家长管控模块挂载
module Api
  module Parental
    class Mount < Grape::API
      mount Api::Parental::ParentalApi
    end
  end
end
