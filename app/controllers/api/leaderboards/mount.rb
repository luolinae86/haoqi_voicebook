# frozen_string_literal: true

module Api
  module Leaderboards
    class Mount < Grape::API
      mount Api::Leaderboards::LeaderboardApi
    end
  end
end
