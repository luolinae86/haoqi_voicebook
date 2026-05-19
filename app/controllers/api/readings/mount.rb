# frozen_string_literal: true

module Api
  module Readings
    class Mount < Grape::API
      mount Api::Readings::ReadingApi
    end
  end
end
