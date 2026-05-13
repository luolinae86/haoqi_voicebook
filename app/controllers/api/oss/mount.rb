# frozen_string_literal: true

module Api
  module Oss
    class Mount < Grape::API
      mount Api::Oss::OssApi
    end
  end
end
