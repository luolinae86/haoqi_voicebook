# frozen_string_literal: true

module Api
  module Channels
    class Mount < Grape::API
      mount Api::Channels::ChannelApi
    end
  end
end