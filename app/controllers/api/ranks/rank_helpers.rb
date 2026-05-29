# frozen_string_literal: true

module Api
  module Ranks
    module RankHelpers
      extend Grape::API::Helpers
      include Api::Oss::OssHelpers

      def serialize_ranks_by_category(ranks)
        result = []
        ranks.group_by(&:category_id).each do |_cat_id, cat_ranks|
          category = cat_ranks.first.category
          next unless category
          result << {
            category_id: category.id,
            category_name: category.name,
            ranks: cat_ranks.sort_by(&:sn).map { |r| { id: r.id, name: r.name, sn: r.sn } }
          }
        end
        result.sort_by { |c| c[:category_id] }
      end

      def serialize_rank_contents(rank)
        rank.rank_contents.order(sn: :asc).map do |rc|
          Entities::RankContent.represent(rc).as_json
        end
      end
    end
  end
end