# frozen_string_literal: true

module Api
  module Ranks
    class RankApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Ranks::RankHelpers

      namespace :ranks do
        before do
          auth_user
        end

        # ==================== 接口一：根据用户年级获取排行榜列表 ====================
        desc '根据用户年级获取排行榜列表（含每个排行榜的内容）'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get '/' do
          grade_id = current_user.grade_id
          error_pop_resp('请先设置年级') if grade_id.blank?

          ranks = Rank.where(grade_id: grade_id)
          present response: success_response(
            categories: serialize_ranks_by_category(ranks)
          )
        end

        # ==================== 接口二：获取指定排行榜下的内容列表 ====================
        desc '获取指定排行榜的内容（图书或合集）'
        params do
          requires :rank_id, type: Integer, desc: '排行榜ID'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get ':rank_id' do
          rank = Rank.find_by(id: params[:rank_id])
          error_pop_resp('排行榜不存在') if rank.blank?

          # 验证排行榜属于当前用户的年级
          error_pop_resp('排行榜不匹配') if rank.grade_id != current_user.grade_id

          present response: success_response(
            rank: {
              id: rank.id,
              name: rank.name,
              category_name: rank.category&.name
            },
            contents: serialize_rank_contents(rank)
          )
        end
      end
    end
  end
end
