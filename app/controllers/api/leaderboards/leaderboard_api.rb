# frozen_string_literal: true

module Api
  module Leaderboards
    class LeaderboardApi < Grape::API
      helpers Api::Concerns::CommonHelpers
      helpers Api::Leaderboards::LeaderboardHelpers

      namespace :leaderboards do
        # ==================== 获取所有启用的排行榜 ====================
        desc '获取所有启用的排行榜列表'
        params do
          requires :uuid, type: String, desc: '用户uuid'
        end
        get '/' do
          auth_user

          leaderboards = serialize_collection(
            Leaderboard.active,
            Entities::Leaderboard
          )
          present response: success_response(leaderboards: leaderboards)
        end

        # ==================== 获取指定排行榜的书籍列表 ====================
        desc '获取指定排行榜的书籍列表'
        params do
          requires :slug, type: String, desc: '排行榜标识'
          requires :uuid, type: String, desc: '用户uuid'
        end
        get ':slug' do
          auth_user

          leaderboard = Leaderboard.find_by(slug: params[:slug], is_active: true)
          error_pop_resp('排行榜不存在') if leaderboard.blank?

          # 自动榜单实时计算
          leaderboard.calculate! if leaderboard.auto? && leaderboard.auto_rule.present?

          items = serialize_collection(
            leaderboard.leaderboard_items.ordered.includes(:book),
            Entities::LeaderboardItem
          )
          present response: success_response(
            leaderboard: { id: leaderboard.id, name: leaderboard.name, slug: leaderboard.slug },
            books: items
          )
        end
      end
    end
  end
end
