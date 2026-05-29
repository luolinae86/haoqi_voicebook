# frozen_string_literal: true

module Api
  module Ranks
    class Mount < Grape::API
      mount Api::Ranks::RankApi
    end
  end
end
