# frozen_string_literal: true

# 排行榜接口
# 提供各类排行榜数据（热度榜、高分榜、上新榜、大奖榜、名著榜）
module Api
  module Rankings
    class RankingApi < Grape::API
      helpers Api::Helpers::CommonHelpers

      namespace :rankings do
        # ==================== 排行榜列表 ====================
        desc "获取排行榜列表"
        params do
          optional :content_type, type: String, desc: "内容类型：ebook/audio/picture_book"
        end
        get do
          rankings = Ranking.all
          present response: success_response, rankings: serialize_collection(rankings, Entities::Ranking)
        end

        # ==================== 排行榜详情 ====================
        desc "获取排行榜详情及图书列表"
        params do
          requires :id, type: Integer, desc: "排行榜ID"
          optional :page, type: Integer, desc: "页码", default: 1
          optional :per_page, type: Integer, desc: "每页数量", default: 20
        end
        get ":id" do
          ranking = Ranking.find(params[:id])
          items = ranking.ranking_items.ordered.includes(:book)
                         .page(params[:page]).per(params[:per_page])

          present response: success_response,
                          ranking_id: ranking.id,
                          name: ranking.name,
                          ranking_type: ranking.ranking_type,
                          books: serialize_collection(items, Entities::RankingItem),
                          pagination: pagination_info(items)
        end
      end
    end
  end
end
