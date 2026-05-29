# frozen_string_literal: true

module Api
  module Ranks
    module RankHelpers
      extend Grape::API::Helpers
      include Api::Oss::OssHelpers

      def serialize_ranks(ranks)
        ranks.order(sn: :asc).map do |rank|
          Entities::Rank.represent(rank).as_json
        end
      end

      def serialize_rank_contents(rank)
        rank.rank_contents.order(sn: :asc).map do |rc|
          Entities::RankContent.represent(rc).as_json
        end
      end
    end
  end
end