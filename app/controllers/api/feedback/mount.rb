# frozen_string_literal: true

module Api
  module Feedback
    class Mount < Grape::API
      mount Api::Feedback::FeedbackApi
    end
  end
end
