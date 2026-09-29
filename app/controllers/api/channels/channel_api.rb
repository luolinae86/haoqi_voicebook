# frozen_string_literal: true

module Api
  module Channels
    class ChannelApi < Grape::API
      helpers Api::Concerns::CommonHelpers

      namespace :channels do
        desc '根据渠道名称获取版本号'
        params do
          requires :channel, type: String, desc: '渠道名称'
        end
        get :version do
          channel = Channel.find_by(name: params[:channel].to_s.strip)

          present response: success_response(
            channel: params[:channel],
            version: channel&.version
          )
        end
      end
    end
  end
end