# frozen_string_literal: true

module Api
  module Home
    class Mount < Grape::API
      mount Api::Home::HomeApi
    end
  end
end
